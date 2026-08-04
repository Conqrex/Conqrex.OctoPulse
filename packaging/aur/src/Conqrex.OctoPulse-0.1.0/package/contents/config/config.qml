import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Account")
        icon: "user-identity"
        source: "configAccount.qml"
    }
    ConfigCategory {
        name: i18n("Repositories")
        icon: "folder-git"
        source: "configRepos.qml"
    }
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
}
