import QtQuick 2.15

QtObject {
    enum MessageType{
        NAME_EXISTENT,
        NAME_ISEMPTY,
        NAME_TOLANG,
        NAME_INVALID,
        COPY_SUCCESSED,
        COPY_FAILED_INSUFFICIENT_SPACE,
        COPY_FAILED_DAMAGED_DRAFT
    }
}
