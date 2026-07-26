import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

TextField {
    placeholderTextColor: config.color
    palette.text: config.color
    font.pointSize: config.fontSize
    font.family: config.font
    width: parent.width
    background: Rectangle {
        color: "#faf2e4"
        opacity: 0.2
        border.width: 1.5
        border.color: "#cac2b4"
        radius: 80
    }
}
