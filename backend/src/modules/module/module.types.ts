export interface InstalledModuleInfo {
    name: string;
    displayName: string;
}

export type BrowseMenuNodeKind = 'app' | 'category' | 'leaf';

export interface BrowseMenuNode {
    id: number;
    name: string;
    kind: BrowseMenuNodeKind;
    model?: string;
    children: BrowseMenuNode[];
}

export interface InstalledModulesResponse {
    modules: InstalledModuleInfo[];
    browseMenuTree: BrowseMenuNode[];
}
