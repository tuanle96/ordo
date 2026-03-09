export interface InstalledModuleInfo {
    name: string;
    displayName: string;
}

export interface InstalledModulesResponse {
    modules: InstalledModuleInfo[];
}
