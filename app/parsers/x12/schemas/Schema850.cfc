component {

    public any function init() {
        return this;
    }

    public struct function getDefinition() {
        return {
            "transactionCode": "850",
            "name": "Purchase Order",
            "version": "005010",
            "functionalGroup": "PO",
            "segments": {
                "ST": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Identifier", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                },
                "BEG": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Transaction Set Purpose Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 2, "name": "Purchase Order Type Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 3, "name": "Purchase Order Number", "type": "AN", "min": 1, "max": 22, "usage": "M"},
                        {"index": 4, "name": "Release Number", "type": "AN", "min": 1, "max": 30, "usage": "O"},
                        {"index": 5, "name": "Date", "type": "DT", "min": 8, "max": 8, "usage": "M"}
                    ]
                },
                "CUR": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Entity Identifier Code", "type": "ID", "min": 2, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Currency Code", "type": "ID", "min": 3, "max": 3, "usage": "M"}
                    ]
                },
                "REF": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Reference Identification Qualifier", "type": "ID", "min": 2, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Reference Identification", "type": "AN", "min": 1, "max": 50, "usage": "M"}
                    ]
                },
                "PER": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Contact Function Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 2, "name": "Name", "type": "AN", "min": 1, "max": 60, "usage": "O"},
                        {"index": 3, "name": "Communication Number Qualifier", "type": "ID", "min": 2, "max": 2, "usage": "O"},
                        {"index": 4, "name": "Communication Number", "type": "AN", "min": 1, "max": 256, "usage": "O"}
                    ]
                },
                "DTM": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Date/Time Qualifier", "type": "ID", "min": 3, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Date", "type": "DT", "min": 8, "max": 8, "usage": "M"}
                    ]
                },
                "N1": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Entity Identifier Code", "type": "ID", "min": 2, "max": 3, "usage": "M"},
                        {"index": 2, "name": "Name", "type": "AN", "min": 1, "max": 60, "usage": "O"},
                        {"index": 3, "name": "Identification Code Qualifier", "type": "ID", "min": 1, "max": 2, "usage": "O"},
                        {"index": 4, "name": "Identification Code", "type": "AN", "min": 2, "max": 80, "usage": "O"}
                    ]
                },
                "N3": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Address Information", "type": "AN", "min": 1, "max": 55, "usage": "M"},
                        {"index": 2, "name": "Address Information 2", "type": "AN", "min": 1, "max": 55, "usage": "O"}
                    ]
                },
                "N4": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "City Name", "type": "AN", "min": 2, "max": 30, "usage": "O"},
                        {"index": 2, "name": "State or Province Code", "type": "ID", "min": 2, "max": 2, "usage": "O"},
                        {"index": 3, "name": "Postal Code", "type": "ID", "min": 3, "max": 15, "usage": "O"},
                        {"index": 4, "name": "Country Code", "type": "ID", "min": 2, "max": 3, "usage": "O"}
                    ]
                },
                "PO1": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Assigned Identification", "type": "AN", "min": 1, "max": 20, "usage": "O"},
                        {"index": 2, "name": "Quantity Ordered", "type": "R", "min": 1, "max": 15, "usage": "M"},
                        {"index": 3, "name": "Unit of Measurement Code", "type": "ID", "min": 2, "max": 2, "usage": "M"},
                        {"index": 4, "name": "Unit Price", "type": "R", "min": 1, "max": 17, "usage": "M"},
                        {"index": 5, "name": "Basis of Unit Price Code", "type": "ID", "min": 2, "max": 2, "usage": "O"},
                        {"index": 6, "name": "Product/Service ID Qualifier", "type": "ID", "min": 2, "max": 2, "usage": "O"},
                        {"index": 7, "name": "Product/Service ID", "type": "AN", "min": 1, "max": 48, "usage": "O"}
                    ]
                },
                "PID": {
                    "usage": "O",
                    "elements": [
                        {"index": 1, "name": "Item Description Type", "type": "ID", "min": 1, "max": 1, "usage": "M"},
                        {"index": 2, "name": "Product/Process Characteristic Code", "type": "ID", "min": 2, "max": 3, "usage": "O"},
                        {"index": 3, "name": "Agency Qualifier Code", "type": "ID", "min": 2, "max": 2, "usage": "O"},
                        {"index": 4, "name": "Product Description Code", "type": "AN", "min": 1, "max": 12, "usage": "O"},
                        {"index": 5, "name": "Description", "type": "AN", "min": 1, "max": 80, "usage": "O"}
                    ]
                },
                "CTT": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Number of Line Items", "type": "N0", "min": 1, "max": 6, "usage": "M"},
                        {"index": 2, "name": "Hash Total", "type": "R", "min": 1, "max": 10, "usage": "O"}
                    ]
                },
                "SE": {
                    "usage": "M",
                    "elements": [
                        {"index": 1, "name": "Number of Included Segments", "type": "N0", "min": 1, "max": 10, "usage": "M"},
                        {"index": 2, "name": "Transaction Set Control Number", "type": "AN", "min": 4, "max": 9, "usage": "M"}
                    ]
                }
            }
        };
    }
}
