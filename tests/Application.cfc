component {
    this.name = "KeystoneTestRunnerApp";
    this.rootDir = getDirectoryFromPath(getCurrentTemplatePath()) & "../";
    this.mappings["/app"] = this.rootDir & "app";
    this.mappings["/tests"] = this.rootDir & "tests";
    this.mappings["/sample_data"] = this.rootDir & "sample_data";
}
