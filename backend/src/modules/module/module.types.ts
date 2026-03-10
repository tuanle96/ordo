export interface InstalledModuleInfo {
    name: string;
    displayName: string;
}

export interface BrowseModelInfo {
    model: string;
    title: string;
}

export interface InstalledModulesResponse {
    modules: InstalledModuleInfo[];
    browseModels: BrowseModelInfo[];
}
