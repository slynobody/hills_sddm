/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import Qt5Compat.GraphicalEffects

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.kirigami 2.20 as Kirigami

import org.kde.breeze.components
import "./components"
// TODO: Once SDDM 0.19 is released and we are setting the font size using the
// SDDM KCM's syncing feature, remove the `config.fontSize` overrides here and
// the fontSize properties in various components, because the theme's default
// font size will be correctly propagated to the login screen

Item {
    id: root

    // If we're using software rendering, draw outlines instead of shadows
    // See https://bugs.kde.org/show_bug.cgi?id=398317
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    Kirigami.Theme.colorSet: Kirigami.Theme.backgroundColor
    Kirigami.Theme.inherit: false

//   width: 1600
//   height: 900

    property string notificationMessage

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

   P5Support.DataSource {
    id: keystateSource
        engine: "keystate"
        connectedSources: "Caps Lock"
}

    Item {
        id: wallpaper
        anchors.fill: parent
        Repeater {
            model: screenModel

            Background {
                x: geometry.x; y: geometry.y; width: geometry.width; height: geometry.height
                sceneBackgroundType: config.type
                sceneBackgroundColor: config.color
                sceneBackgroundImage: config.background
            }
        }
    }

    RejectPasswordAnimation {
        id: rejectPasswordAnimation
        target: stackShadow
        //target: mainStack
    }

    MouseArea {
        id: loginScreenRoot
        anchors.fill: parent

       property bool uiVisible: true
        property bool blockUI: mainStack.depth > 1 || userListComponent.mainPasswordBox.text.length > 0 || inputPanel.keyboardActive || config.type !== "image"

        hoverEnabled: true
        drag.filterChildren: true
        onPressed: uiVisible = false;
        onPositionChanged: uiVisible = false;
        onUiVisibleChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
            } else if (uiVisible) {
                fadeoutTimer.restart();
            }
        }
        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
                uiVisible = false;
            } else {
                fadeoutTimer.restart();
                uiVisible = true;
            }
        }

        Keys.onPressed: event => {
            uiVisible = false;
            event.accepted = false;
        }

        //takes one full minute for the ui to disappear
        Timer {
            id: fadeoutTimer
            running: true
            interval: units.verylongDuration
            onTriggered: {
                if (!loginScreenRoot.blockUI) {
                    userListComponent.mainPasswordBox.showPassword = true;
                    loginScreenRoot.uiVisible = false;
                }
            }
        }
        WallpaperFader {
            visible: config.type === "image"
            anchors.fill: parent
            state: loginScreenRoot.uiVisible ? "off" : "on"
            source: wallpaper
            mainStack: mainStack
            footer: footer
            clock: clock
        }

        DropShadow {
            id: clockShadow
            anchors.fill: clock
            source: clock
            visible: !softwareRendering
            radius: 4
            samples: 14
            spread: 0.6
            color : "black" // shadows should always be black
            Behavior on opacity {
                OpacityAnimator {
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.InOutQuad
                }
            }
        }

       DropShadow {
            id: stackShadow
            anchors.fill: mainStack
            source: mainStack
            visible: !softwareRendering
            radius: 4
            samples: 10
            spread: 0.4
            color : "black" // shadows should always be black
            Behavior on opacity {
                OpacityAnimator {
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.InOutQuad
                }
            }
        }

        DropShadow {
            id: footerShadow
            anchors.fill: footer
            source: footer
            visible: !softwareRendering
            radius: 7
            samples: 14
            spread: 0.4
            color : "black" // shadows should always be black
            Behavior on opacity {
                OpacityAnimator {
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.InOutQuad
                }
            }
        }
 //       Clock {
 //           id: clock
 //           property Item shadow: clockShadow
 //           visible: y > 0
 //           anchors.horizontalCenter: parent.horizontalCenter
 //           y: (userListComponent.userList.y + mainStack.y)/2.15 - height/1.1
 //           Layout.alignment: Qt.AlignBaseline
 //       }

        QQC2.StackView {
            id: mainStack
            property Item shadow: stackShadow
            anchors {
                left: parent.left
                right: parent.right
            }
           height: root.height + Kirigami.Units.gridUnit * 15.2

            // If true (depends on the style and environment variables), hover events are always accepted
            // and propagation stopped. This means the parent MouseArea won't get them and the UI won't be shown.
            // Disable capturing those events while the UI is hidden to avoid that, while still passing events otherwise.
            // One issue is that while the UI is visible, mouse activity won't keep resetting the timer, but when it
            // finally expires, the next event should immediately set uiVisible = true again.
            hoverEnabled: loginScreenRoot.uiVisible ? undefined : false

            focus: true //StackView is an implicit focus scope, so we need to give this focus so the item inside will have it

            Timer {
                //SDDM has a bug in 0.13 where even though we set the focus on the right item within the window, the window doesn't have focus
                //it is fixed in 6d5b36b28907b16280ff78995fef764bb0c573db which will be 0.14
                //we need to call "window->activate()" *After* it's been shown. We can't control that in QML so we use a shoddy timer
                //it's been this way for all Plasma 5.x without a huge problem
                running: true
                repeat: false
                interval: 200
                onTriggered: mainStack.forceActiveFocus()
            }

            initialItem: Login {
                id: userListComponent
                userListModel: userModel
                loginScreenUiVisible: loginScreenRoot.uiVisible

                userListCurrentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
                lastUserName: userModel.lastUser
                showUserList: {
                    if (!userListModel.hasOwnProperty("count")
                        || !userListModel.hasOwnProperty("disableAvatarsThreshold")) {
                        return false
                    }

                    if (userListModel.count === 0 ) {
                        return false
                    }

                    if (userListModel.hasOwnProperty("containsAllUsers") && !userListModel.containsAllUsers) {
                        return false
                    }

                    return userListModel.count <= userListModel.disableAvatarsThreshold
                }

                notificationMessage: {
                    const parts = [];
                    if (keystateSource.data["Caps Lock"]["Locked"]) {
                        parts.push(i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Caps Lock is on"));
                    }
                    if (root.notificationMessage) {
                        parts.push(root.notificationMessage);
                    }
                    return parts.join(" • ");
                }

                actionItemsVisible: !inputPanel.keyboardActive
                                     // y: height/165

                actionItems: [
                    ActionButton {
                                         icon.name: "/usr/share/sddm/themes/Integr/assets/shutdown_primary.svgz"
                     //   text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Shut Down")
                        onClicked: sddm.powerOff()
                        enabled: sddm.canPowerOff
                    },
                    ActionButton {
                icon.name: "/usr/share/sddm/themes/Integr/assets/restart_primary.svgz"
                     //   text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Restart")
                        onClicked: sddm.reboot()
                        enabled: sddm.canReboot
                    },
                    ActionButton {
                   icon.name : "/usr/share/sddm/themes/Integr/assets/suspend_primary.svgz"
                     //   text: i18ndc("plasma_lookandfeel_org.kde.lookandfeel", "Suspend to RAM", "Sleep")
                        onClicked: sddm.suspend()
                        enabled: sddm.canSuspend
                    },
                    ActionButton {
                 icon.name: "/usr/share/sddm/themes/Integr/assets/switch_primary.svgz"
                     //   text: i18ndc("plasma_lookandfeel_org.kde.lookandfeel", "For switching to a username and password prompt", "Other…")
                        onClicked: mainStack.push(userPromptComponent)
                        enabled: true
                        visible: !userListComponent.showUsernamePrompt
                    }]

                onLoginRequest: {
                    root.notificationMessage = ""
                    sddm.login(username, password, sessionButton.currentIndex)
                }
            }

            Behavior on opacity {
           
                OpacityAnimator {
                    duration: Kirigami.Units.veryLongDuration *1.8
                }
            }

            readonly property real zoomFactor: 1.7

            popEnter: Transition {
                ScaleAnimator {
                    from: mainStack.zoomFactor
                    to: 1
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.OutElastic
                }
                OpacityAnimator {
                    from: 0
                    to: 1
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.OutElastic
                }
            }

            popExit: Transition {
                ScaleAnimator {
                    from: 1
                    to: 1 / mainStack.zoomFactor
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.OutElastic
                }
                OpacityAnimator {
                    from: 1
                    to: 0
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.OutElastic
                }
            }

            pushEnter: Transition {
                ScaleAnimator {
                    from: 1 / mainStack.zoomFactor
                    to: 1
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.OutElastic
                }
                OpacityAnimator {
                    from: 0
                    to: 1
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.OutElastic
                }
            }

            pushExit: Transition {
                ScaleAnimator {
                    from: 1
                    to: mainStack.zoomFactor
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.OutElastic
                }
                OpacityAnimator {
                    from: 1
                    to: 0
                    duration: Kirigami.Units.veryLongDuration *1.8
                    easing.type: Easing.OutElastic
                }
            }
        }

        VirtualKeyboardLoader {
            id: inputPanel
            z: 1
            screenRoot: root
            mainStack: mainStack
            mainBlock: userListComponent
            passwordField: userListComponent.mainPasswordBox

        }

        Component {
            id: userPromptComponent
            Login {
                showUsernamePrompt: true
                notificationMessage: root.notificationMessage
                loginScreenUiVisible: loginScreenRoot.uiVisible

                // using a model rather than a QObject list to avoid QTBUG-75900
                userListModel: ListModel {
                    ListElement {
                        name: ""
                        icon: ""
                    }
                    Component.onCompleted: {
                        // as we can't bind inside ListElement
                        setProperty(0, "name", i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Type in Username and Password"));
                        setProperty(0, "icon", Qt.resolvedUrl("faces/.face.icon"))
                    }
                }

                onLoginRequest: {
                    root.notificationMessage = ""
                    sddm.login(username, password, sessionButton.currentIndex)
                }

                actionItemsVisible: !inputPanel.keyboardActive
                actionItems: [
                    ActionButton {
                    icon.name:  "/usr/share/sddm/themes/Integr/assets/suspend_primary.svgz"
                     //   text: i18ndc("plasma_lookandfeel_org.kde.lookandfeel", "Suspend to RAM", "Sleep")
                        onClicked: sddm.suspend()
                        enabled: sddm.canSuspend
                    },
                    ActionButton {
                    icon.name:  "/usr/share/sddm/themes/Integr/assets/restart_primary.svgz"
                    //    text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Restart")
                        onClicked: sddm.reboot()
                        enabled: sddm.canReboot
                    },
                    ActionButton {
                        icon.name:  "/usr/share/sddm/themes/Integr/assets/shutdown_primary.svgz"
                     //   text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Shut Down")
                        onClicked: sddm.powerOff()
                        enabled: sddm.canPowerOff
                    },
                    ActionButton {
                    icon.name:  "/usr/share/sddm/themes/Integr/assets/switch_primary.svgz"
                    //    text: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "List Users")
                        onClicked: mainStack.pop()
                    }
                ]
            }
        }

        DropShadow {
            id: logoShadow
            anchors.fill: logo
            source: logo
            visible: !softwareRendering && config.showlogo === "shown"
            horizontalOffset: 1
            verticalOffset: 1
            radius: 6
            samples: 14
            spread: 0.3
            color : "black" // shadows should always be black
            opacity: loginScreenRoot.uiVisible ? 0 : 0.8
            Behavior on opacity {
                //OpacityAnimator when starting from 0 is buggy (it shows one frame with opacity 1)"
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Image {
            id: logo
            visible: config.showlogo === "shown"
            source: config.logo
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: footer.top
            anchors.bottomMargin: Kirigami.Units.largeSpacing
            asynchronous: true
            sourceSize.height: height
            opacity: loginScreenRoot.uiVisible ? 0 : 0.8
            fillMode: Image.PreserveAspectFit
            height: Math.round(Kirigami.Units.gridUnit * 3.5)
            Behavior on opacity {
                // OpacityAnimator when starting from 0 is buggy (it shows one frame with opacity 1)"
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // Note: Containment masks stretch clickable area of their buttons to
        // the screen edges, essentially making them adhere to Fitts's law.
        // Due to virtual keyboard button having an icon, buttons may have
        // different heights, so fillHeight is required.
        //
        // Note for contributors: Keep this in sync with LockScreenUi.qml footer.
        RowLayout {
            id: footer
                property Item shadow: footerShadow
            anchors {
//          bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter

            // left: parent.horizontalCenter
              //  margins: Kirigami.Units.smallSpacing
             Layout.alignment: Qt.AlignBaseline
            }

            spacing: Kirigami.Units.smallSpacing

            Behavior on opacity {
                OpacityAnimator {
                    duration: Kirigami.Units.longDuration
                }
            }


                       PlasmaComponents3.ToolButton {
                id: virtualKeyboardButton

                text: i18ndc("plasma_lookandfeel_org.kde.lookandfeel", "Button to show/hide virtual keyboard", "")
                icon.name: inputPanel.keyboardActive ? "input-keyboard-virtual-on" : "input-keyboard-virtual-off"
                onClicked: {
                    // Otherwise the password field loses focus and virtual keyboard
                    // keystrokes get eaten
                    userListComponent.mainPasswordBox.forceActiveFocus();
                    inputPanel.showHide()
                }
            // visible: false

         Layout.fillHeight: true
                containmentMask: Item {
                    parent: virtualKeyboardButton
               anchors.fill: parent
               anchors.leftMargin: -footer.anchors.margins
               anchors.bottomMargin: -footer.anchors.margins
                }

            }

           KeyboardButton { id: keyboardButton


                onKeyboardLayoutChanged: {
                    // Otherwise the password field loses focus and virtual keyboard
                    // keystrokes get eaten
                    userListComponent.mainPasswordBox.forceActiveFocus();
                }

                Layout.fillHeight: true
                containmentMask: Item {
                    parent: keyboardButton
                    anchors.fill: parent
                   anchors.leftMargin: virtualKeyboardButton.visible ? 0 : -footer.anchors.margins
                   anchors.bottomMargin: -footer.anchors.margins
                }
            }

            SessionButton { id: sessionButton

                onSessionChanged: {
                    // Otherwise the password field loses focus and virtual keyboard
                    // keystrokes get eaten
                    userListComponent.mainPasswordBox.forceActiveFocus();
                }

                Layout.fillHeight: true
                containmentMask: Item {
                    parent: sessionButton

              anchors.fill: parent
                anchors.leftMargin: virtualKeyboardButton.visible || keyboardButton.visible
                      ? 0 : -footer.anchors.margins
                anchors.bottomMargin: -footer.anchors.margins
                }
            }



          Item {
             Layout.fillWidth: true
           }

            Battery {
                fontSize: config.fontSize
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            notificationMessage = i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Login Failed")
            footer.enabled = true

         mainStack.enabled = false
         mainStack.visible = false
          stackShadow.enabled = true
          stackShadow.visible = true

          //ToolButton.visible = true

            userListComponent.userList.opacity = 0.6
            footer.opacity = 0.8
            clockShadow.opacity = 0.8

            rejectPasswordAnimation.start()

            mainStack.enabled = true
            mainStack.visible = true

            //stackShadow.enabled = true
            //stackShadow.visible = true
           // footer.visible = true

            userListComponent.userList.opacity = 1
            footer.opacity = 1
            clockShadow.opacity = 1
        }
        function onLoginSucceeded() {
            //note SDDM will kill the greeter at some random point after this
            //there is no certainty any transition will finish, it depends on the time it
            //takes to complete the init
            mainStack.opacity = 1
            footer.opacity = 1
        }
    }

    onNotificationMessageChanged: {
        if (notificationMessage) {
            notificationResetTimer.start();
        }
    }

    Timer {
        id: notificationResetTimer
        interval: 300
        onTriggered: notificationMessage = ""
    }
}
