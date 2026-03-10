export interface InstalledModuleInfo {
    name: string;
    displayName: string;
}

export type BrowseMenuNodeKind = 'app' | 'category' | 'leaf';
export type BrowsePreferredViewMode = 'list' | 'kanban';

export interface BrowseMenuNode {
    id: number;
    name: string;
    kind: BrowseMenuNodeKind;
    model?: string;
    preferredViewMode?: BrowsePreferredViewMode;
    children: BrowseMenuNode[];
}

export interface InstalledModulesResponse {
    modules: InstalledModuleInfo[];
    browseMenuTree: BrowseMenuNode[];
}
