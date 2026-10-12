fn main() {
    cxx_qt_build::CxxQtBuilder::new()
        .qrc("../../original/original.qrc")
        .qt_module("Gui")
        .qt_module("Qml")
        .build();
}
