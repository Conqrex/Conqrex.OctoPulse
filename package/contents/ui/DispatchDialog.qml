import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// workflow_dispatch launcher. Reads the workflow file, extracts the
// `on.workflow_dispatch.inputs` block with a small indentation-based scan
// (good enough for common workflows), and renders a form: ref + inputs.
QQC2.Dialog {
    id: dlg

    property var poller
    property string repo: ""
    property var workflowId: 0
    property string workflowPath: ""
    property string defaultRef: ""

    // [{name, description, def, type, options[]}]
    property var inputs: []
    property bool parsing: false
    property string statusMsg: ""
    property bool sending: false

    title: i18n("Run workflow — %1", repo)
    modal: true
    standardButtons: QQC2.Dialog.NoButton
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - Kirigami.Units.gridUnit * 2 : 400,
                    Kirigami.Units.gridUnit * 24)

    function openFor(m) {
        repo = m.repo;
        workflowId = m.workflowId;
        workflowPath = m.workflowPath;
        defaultRef = m.branch || "main";
        refField.text = defaultRef;
        inputs = [];
        statusMsg = "";
        parsing = true;
        open();
        poller.fetchWorkflowFile(repo, workflowPath, function (text) {
            dlg.parsing = false;
            if (text) dlg.inputs = dlg.parseInputs(text);
        });
    }

    // Scan YAML for workflow_dispatch: -> inputs: -> one level of input names
    // with optional description/default/type/options.
    function parseInputs(yaml) {
        var lines = yaml.split("\n");
        var out = [];
        var inDispatch = false, inInputs = false;
        var dispatchIndent = -1, inputsIndent = -1, nameIndent = -1;
        var cur = null;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (/^\s*#/.test(line) || /^\s*$/.test(line)) continue;
            var indent = line.match(/^\s*/)[0].length;
            var m;
            if ((m = line.match(/^(\s*)workflow_dispatch:\s*$/))) {
                inDispatch = true; inInputs = false;
                dispatchIndent = m[1].length; cur = null;
                continue;
            }
            if (inDispatch && indent <= dispatchIndent) { inDispatch = false; inInputs = false; cur = null; }
            if (inDispatch && (m = line.match(/^(\s*)inputs:\s*$/))) {
                inInputs = true; inputsIndent = m[1].length; nameIndent = -1; cur = null;
                continue;
            }
            if (!inInputs) continue;
            if (indent <= inputsIndent) { inInputs = false; cur = null; continue; }
            if ((m = line.match(/^(\s*)([A-Za-z0-9_-]+):\s*$/)) && (nameIndent < 0 || m[1].length === nameIndent)) {
                nameIndent = m[1].length;
                cur = { name: m[2], description: "", def: "", type: "string", options: [] };
                out.push(cur);
                continue;
            }
            if (cur && indent > nameIndent) {
                if ((m = line.match(/^\s*description:\s*["']?(.*?)["']?\s*$/))) cur.description = m[1];
                else if ((m = line.match(/^\s*default:\s*["']?(.*?)["']?\s*$/))) cur.def = m[1];
                else if ((m = line.match(/^\s*type:\s*(\S+)\s*$/))) cur.type = m[1];
                else if ((m = line.match(/^\s*-\s*["']?(.*?)["']?\s*$/))) cur.options.push(m[1]);
            }
        }
        return out;
    }

    function send() {
        sending = true;
        statusMsg = "";
        var vals = {};
        for (var i = 0; i < inputRepeater.count; i++) {
            var item = inputRepeater.itemAt(i);
            if (item) vals[item.inputName] = item.value;
        }
        poller.dispatch(repo, workflowId, refField.text.trim(), vals, function (ok, msg) {
            dlg.sending = false;
            dlg.statusMsg = ok ? i18n("✔ Workflow dispatched") : i18n("✘ %1", msg);
        });
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        QQC2.BusyIndicator {
            visible: dlg.parsing
            Layout.alignment: Qt.AlignHCenter
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.TextField {
                id: refField
                Kirigami.FormData.label: i18n("Branch / ref:")
            }

            Repeater {
                id: inputRepeater
                model: dlg.inputs

                delegate: RowLayout {
                    required property var modelData
                    readonly property string inputName: modelData.name
                    readonly property string value:
                        modelData.type === "boolean" ? (boolBox.checked ? "true" : "false")
                      : modelData.type === "choice" ? choiceBox.currentText
                      : textField.text
                    Kirigami.FormData.label: modelData.name + ":"

                    QQC2.TextField {
                        id: textField
                        visible: modelData.type !== "boolean" && modelData.type !== "choice"
                        text: modelData.def
                        placeholderText: modelData.description
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    }
                    QQC2.CheckBox {
                        id: boolBox
                        visible: modelData.type === "boolean"
                        checked: modelData.def === "true"
                        text: modelData.description
                    }
                    QQC2.ComboBox {
                        id: choiceBox
                        visible: modelData.type === "choice"
                        model: modelData.options
                        currentIndex: Math.max(0, modelData.options.indexOf(modelData.def))
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    }
                }
            }
        }

        QQC2.Label {
            visible: dlg.statusMsg !== ""
            text: dlg.statusMsg
            color: dlg.statusMsg.indexOf("✔") === 0
                   ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            QQC2.Button {
                text: i18n("Close")
                onClicked: dlg.close()
            }
            QQC2.Button {
                text: i18n("Run workflow")
                icon.name: "media-playback-start"
                enabled: !dlg.sending && !dlg.parsing && refField.text.trim() !== ""
                onClicked: dlg.send()
            }
        }
    }
}
