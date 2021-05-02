component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "messageType": "ORU",
            "name": "Observational Report / Lab Result",
            "version": "2.5.1",
            "segments": {
                "MSH": {"usage": "M", "description": "Message Header"},
                "PID": {"usage": "M", "description": "Patient Identification"},
                "PV1": {"usage": "O", "description": "Patient Visit"},
                "ORC": {"usage": "O", "description": "Common Order"},
                "OBR": {"usage": "M", "description": "Observation Request"},
                "OBX": {"usage": "M", "description": "Observation / Result"},
                "NTE": {"usage": "O", "description": "Notes and Comments"}
            }
        };
    }
}
