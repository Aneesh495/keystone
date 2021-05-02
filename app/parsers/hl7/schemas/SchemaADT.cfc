component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "messageType": "ADT",
            "name": "Admit, Discharge, Transfer",
            "version": "2.5.1",
            "segments": {
                "MSH": {"usage": "M", "description": "Message Header"},
                "EVN": {"usage": "M", "description": "Event Type"},
                "PID": {"usage": "M", "description": "Patient Identification"},
                "PD1": {"usage": "O", "description": "Additional Demographics"},
                "PV1": {"usage": "M", "description": "Patient Visit Information"},
                "PV2": {"usage": "O", "description": "Patient Visit Additional Information"},
                "AL1": {"usage": "O", "description": "Allergy Information"},
                "DG1": {"usage": "O", "description": "Diagnosis Information"}
            }
        };
    }
}
