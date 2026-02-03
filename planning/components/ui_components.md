# UI Components

Scope: ECS UI-related components extracted from C++ headers.

Critical gotchas:
- UIBoxComponent.uiRoot must move with Transform to keep UI visible and interactive.
- ScreenSpaceCollisionMarker is required for UI click detection in screen space.
- Avoid storing state directly on GameObject; use script tables for UI state.

## AtlasSelection
**doc_id:** `component:AtlasSelection`
**Location:** `src/systems/ui/editor/pack_editor.hpp:13`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| active | bool | false |  |
| start | Vector2 | 0, 0 |  |
| end | Vector2 | 0, 0 |  |

## ButtonDef
**doc_id:** `component:ButtonDef`
**Location:** `src/systems/ui/ui_pack.hpp:25`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| normal | RegionDef | None |  |
| hover | std::optional<RegionDef> | None |  |
| pressed | std::optional<RegionDef> | None |  |
| disabled | std::optional<RegionDef> | None |  |

## EditContext
**doc_id:** `component:EditContext`
**Location:** `src/systems/ui/editor/pack_editor.hpp:56`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| elementType | PackElementType | PackElementType::Panel |  |
| variantName | std::string | None |  |
| buttonState | ButtonState | ButtonState::Normal |  |
| scaleMode | SpriteScaleMode | SpriteScaleMode::Stretch |  |
| useNinePatch | bool | true |  |
| guides | NinePatchGuides | None |  |

## IUIElementHandler
**doc_id:** `component:IUIElementHandler`
**Location:** `src/systems/ui/handlers/handler_interface.hpp:56`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImBitArray
**doc_id:** `component:ImBitArray`
**Location:** `src/third_party/rlImGui/imgui_internal.h:593`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImChunkStream
**doc_id:** `component:ImChunkStream`
**Location:** `src/third_party/rlImGui/imgui_internal.h:709`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Buf | ImVector<char> | None |  |

## ImColor
**doc_id:** `component:ImColor`
**Location:** `src/third_party/rlImGui/imgui.h:2652`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Value | ImVec4 | None |  |

## ImDrawChannel
**doc_id:** `component:ImDrawChannel`
**Location:** `src/third_party/rlImGui/imgui.h:2909`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| _CmdBuffer | ImVector<ImDrawCmd> | None |  |
| _IdxBuffer | ImVector<ImDrawIdx> | None |  |

## ImDrawCmd
**doc_id:** `component:ImDrawCmd`
**Location:** `src/third_party/rlImGui/imgui.h:2868`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ClipRect | ImVec4 | None |  |
| TextureId | ImTextureID | None |  |
| UserCallback | ImDrawCallback | None |  |
| UserCallbackData | void* | None |  |

## ImDrawCmdHeader
**doc_id:** `component:ImDrawCmdHeader`
**Location:** `src/third_party/rlImGui/imgui.h:2901`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ClipRect | ImVec4 | None |  |
| TextureId | ImTextureID | None |  |

## ImDrawData
**doc_id:** `component:ImDrawData`
**Location:** `src/third_party/rlImGui/imgui.h:3113`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Valid | bool | None |  |
| CmdListsCount | int | None |  |
| TotalIdxCount | int | None |  |
| TotalVtxCount | int | None |  |
| CmdLists | ImVector<ImDrawList*> | None |  |
| DisplayPos | ImVec2 | None |  |
| DisplaySize | ImVec2 | None |  |
| FramebufferScale | ImVec2 | None |  |
| OwnerViewport | ImGuiViewport* | None |  |

## ImDrawDataBuilder
**doc_id:** `component:ImDrawDataBuilder`
**Location:** `src/third_party/rlImGui/imgui_internal.h:796`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| LayerData1 | ImVector<ImDrawList*> | None |  |

## ImDrawList
**doc_id:** `component:ImDrawList`
**Location:** `src/third_party/rlImGui/imgui.h:2973`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| CmdBuffer | ImVector<ImDrawCmd> | None |  |
| IdxBuffer | ImVector<ImDrawIdx> | None |  |
| VtxBuffer | ImVector<ImDrawVert> | None |  |
| Flags | ImDrawListFlags | None |  |
| _Data | ImDrawListSharedData* | None |  |
| _VtxWritePtr | ImDrawVert* | None |  |
| _IdxWritePtr | ImDrawIdx* | None |  |
| _Path | ImVector<ImVec2> | None |  |
| _CmdHeader | ImDrawCmdHeader | None |  |
| _Splitter | ImDrawListSplitter | None |  |
| _ClipRectStack | ImVector<ImVec4> | None |  |
| _TextureIdStack | ImVector<ImTextureID> | None |  |
| _FringeScale | float | None |  |
| _OwnerName | char* | None |  |

## ImDrawListSplitter
**doc_id:** `component:ImDrawListSplitter`
**Location:** `src/third_party/rlImGui/imgui.h:2918`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| _Current | int | None |  |
| _Count | int | None |  |
| _Channels | ImVector<ImDrawChannel> | None |  |

## ImDrawVert
**doc_id:** `component:ImDrawVert`
**Location:** `src/third_party/rlImGui/imgui.h:2886`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| pos | ImVec2 | None |  |
| uv | ImVec2 | None |  |
| col | ImU32 | None |  |

## ImFont
**doc_id:** `component:ImFont`
**Location:** `src/third_party/rlImGui/imgui.h:3336`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| IndexAdvanceX | ImVector<float> | None |  |
| FallbackAdvanceX | float | None |  |
| FontSize | float | None |  |
| IndexLookup | ImVector<ImWchar> | None |  |
| Glyphs | ImVector<ImFontGlyph> | None |  |
| FallbackGlyph | ImFontGlyph* | None |  |
| ContainerAtlas | ImFontAtlas* | None |  |
| ConfigData | ImFontConfig* | None |  |
| ConfigDataCount | short | None |  |
| FallbackChar | ImWchar | None |  |
| EllipsisChar | ImWchar | None |  |
| EllipsisCharCount | short | None |  |
| EllipsisWidth | float | None |  |
| EllipsisCharStep | float | None |  |
| DirtyLookupTables | bool | None |  |
| Scale | float | None |  |
| MetricsTotalSurface | int | None |  |

## ImFontAtlas
**doc_id:** `component:ImFontAtlas`
**Location:** `src/third_party/rlImGui/imgui.h:3232`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Flags | ImFontAtlasFlags | None |  |
| TexID | ImTextureID | None |  |
| TexDesiredWidth | int | None |  |
| TexGlyphPadding | int | None |  |
| Locked | bool | None |  |
| UserData | void* | None |  |
| TexReady | bool | None |  |
| TexPixelsUseColors | bool | None |  |
| TexWidth | int | None |  |
| TexHeight | int | None |  |
| TexUvScale | ImVec2 | None |  |
| TexUvWhitePixel | ImVec2 | None |  |
| Fonts | ImVector<ImFont*> | None |  |
| CustomRects | ImVector<ImFontAtlasCustomRect> | None |  |
| ConfigData | ImVector<ImFontConfig> | None |  |
| FontBuilderIO | ImFontBuilderIO* | None |  |
| PackIdMouseCursors | int | None |  |
| PackIdLines | int | None |  |

## ImFontAtlasCustomRect
**doc_id:** `component:ImFontAtlasCustomRect`
**Location:** `src/third_party/rlImGui/imgui.h:3194`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| GlyphAdvanceX | float | None |  |
| GlyphOffset | ImVec2 | None |  |
| Font | ImFont* | None |  |

## ImFontBuilderIO
**doc_id:** `component:ImFontBuilderIO`
**Location:** `src/third_party/rlImGui/imgui_internal.h:3579`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImFontConfig
**doc_id:** `component:ImFontConfig`
**Location:** `src/third_party/rlImGui/imgui.h:3137`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| FontData | void* | None |  |
| FontDataSize | int | None |  |
| FontDataOwnedByAtlas | bool | None |  |
| FontNo | int | None |  |
| SizePixels | float | None |  |
| OversampleH | int | None |  |
| OversampleV | int | None |  |
| PixelSnapH | bool | None |  |
| GlyphExtraSpacing | ImVec2 | None |  |
| GlyphOffset | ImVec2 | None |  |
| GlyphRanges | ImWchar* | None |  |
| GlyphMinAdvanceX | float | None |  |
| GlyphMaxAdvanceX | float | None |  |
| MergeMode | bool | None |  |
| RasterizerMultiply | float | None |  |
| RasterizerDensity | float | None |  |
| EllipsisChar | ImWchar | None |  |
| DstFont | ImFont* | None |  |

## ImFontGlyph
**doc_id:** `component:ImFontGlyph`
**Location:** `src/third_party/rlImGui/imgui.h:3167`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| AdvanceX | float | None |  |

## ImFontGlyphRangesBuilder
**doc_id:** `component:ImFontGlyphRangesBuilder`
**Location:** `src/third_party/rlImGui/imgui.h:3179`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| UsedChars | ImVector<ImU32> | None |  |

## ImGuiColorMod
**doc_id:** `component:ImGuiColorMod`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1033`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Col | ImGuiCol | None |  |
| BackupValue | ImVec4 | None |  |

## ImGuiContext
**doc_id:** `component:ImGuiContext`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1921`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Initialized | bool | None |  |
| FontAtlasOwnedByContext | bool | None |  |
| IO | ImGuiIO | None |  |
| Style | ImGuiStyle | None |  |
| Font | ImFont* | None |  |
| FontSize | float | None |  |
| FontBaseSize | float | None |  |
| CurrentDpiScale | float | None |  |
| DrawListSharedData | ImDrawListSharedData | None |  |
| Time | double | None |  |
| FrameCount | int | None |  |
| FrameCountEnded | int | None |  |
| FrameCountRendered | int | None |  |
| WithinFrameScope | bool | None |  |
| WithinFrameScopeWithImplicitWindow | bool | None |  |
| WithinEndChild | bool | None |  |
| GcCompactAll | bool | None |  |
| TestEngineHookItems | bool | None |  |
| TestEngine | void* | None |  |
| InputEventsQueue | ImVector<ImGuiInputEvent> | None |  |
| InputEventsTrail | ImVector<ImGuiInputEvent> | None |  |
| InputEventsNextMouseSource | ImGuiMouseSource | None |  |
| InputEventsNextEventId | ImU32 | None |  |
| Windows | ImVector<ImGuiWindow*> | None |  |
| WindowsFocusOrder | ImVector<ImGuiWindow*> | None |  |
| WindowsTempSortBuffer | ImVector<ImGuiWindow*> | None |  |
| CurrentWindowStack | ImVector<ImGuiWindowStackData> | None |  |
| WindowsById | ImGuiStorage | None |  |
| WindowsActiveCount | int | None |  |
| WindowsHoverPadding | ImVec2 | None |  |
| DebugBreakInWindow | ImGuiID | None |  |
| CurrentWindow | ImGuiWindow* | None |  |
| HoveredWindow | ImGuiWindow* | None |  |
| HoveredWindowUnderMovingWindow | ImGuiWindow* | None |  |
| HoveredWindowBeforeClear | ImGuiWindow* | None |  |
| MovingWindow | ImGuiWindow* | None |  |
| WheelingWindow | ImGuiWindow* | None |  |
| WheelingWindowRefMousePos | ImVec2 | None |  |
| WheelingWindowStartFrame | int | None |  |
| WheelingWindowScrolledFrame | int | None |  |
| WheelingWindowReleaseTimer | float | None |  |
| WheelingWindowWheelRemainder | ImVec2 | None |  |
| WheelingAxisAvg | ImVec2 | None |  |
| DebugHookIdInfo | ImGuiID | None |  |
| HoveredId | ImGuiID | None |  |
| HoveredIdPreviousFrame | ImGuiID | None |  |
| HoveredIdTimer | float | None |  |
| HoveredIdNotActiveTimer | float | None |  |
| HoveredIdAllowOverlap | bool | None |  |
| HoveredIdIsDisabled | bool | None |  |
| ItemUnclipByLog | bool | None |  |
| ActiveId | ImGuiID | None |  |
| ActiveIdIsAlive | ImGuiID | None |  |
| ActiveIdTimer | float | None |  |
| ActiveIdIsJustActivated | bool | None |  |
| ActiveIdAllowOverlap | bool | None |  |
| ActiveIdNoClearOnFocusLoss | bool | None |  |
| ActiveIdHasBeenPressedBefore | bool | None |  |
| ActiveIdHasBeenEditedBefore | bool | None |  |
| ActiveIdHasBeenEditedThisFrame | bool | None |  |
| ActiveIdFromShortcut | bool | None |  |
| ActiveIdClickOffset | ImVec2 | None |  |
| ActiveIdWindow | ImGuiWindow* | None |  |
| ActiveIdSource | ImGuiInputSource | None |  |
| ActiveIdPreviousFrame | ImGuiID | None |  |
| ActiveIdPreviousFrameIsAlive | bool | None |  |
| ActiveIdPreviousFrameHasBeenEditedBefore | bool | None |  |
| ActiveIdPreviousFrameWindow | ImGuiWindow* | None |  |
| LastActiveId | ImGuiID | None |  |
| LastActiveIdTimer | float | None |  |
| LastKeyModsChangeTime | double | None |  |
| LastKeyModsChangeFromNoneTime | double | None |  |
| LastKeyboardKeyPressTime | double | None |  |
| KeysMayBeCharInput | ImBitArrayForNamedKeys | None |  |
| KeysRoutingTable | ImGuiKeyRoutingTable | None |  |
| ActiveIdUsingNavDirMask | ImU32 | None |  |
| ActiveIdUsingAllKeyboardKeys | bool | None |  |
| DebugBreakInShortcutRouting | ImGuiKeyChord | None |  |
| ActiveIdUsingNavInputMask | ImU32 | None |  |
| CurrentFocusScopeId | ImGuiID | None |  |
| CurrentItemFlags | ImGuiItemFlags | None |  |
| DebugLocateId | ImGuiID | None |  |
| NextItemData | ImGuiNextItemData | None |  |
| LastItemData | ImGuiLastItemData | None |  |
| NextWindowData | ImGuiNextWindowData | None |  |
| DebugShowGroupRects | bool | None |  |
| DebugFlashStyleColorIdx | ImGuiCol | None |  |
| ColorStack | ImVector<ImGuiColorMod> | None |  |
| StyleVarStack | ImVector<ImGuiStyleMod> | None |  |
| FontStack | ImVector<ImFont*> | None |  |
| FocusScopeStack | ImVector<ImGuiFocusScopeData> | None |  |
| ItemFlagsStack | ImVector<ImGuiItemFlags> | None |  |
| GroupStack | ImVector<ImGuiGroupData> | None |  |
| OpenPopupStack | ImVector<ImGuiPopupData> | None |  |
| BeginPopupStack | ImVector<ImGuiPopupData> | None |  |
| NavTreeNodeStack | ImVector<ImGuiNavTreeNodeData> | None |  |
| Viewports | ImVector<ImGuiViewportP*> | None |  |
| NavWindow | ImGuiWindow* | None |  |
| NavId | ImGuiID | None |  |
| NavFocusScopeId | ImGuiID | None |  |
| NavLayer | ImGuiNavLayer | None |  |
| NavActivateId | ImGuiID | None |  |
| NavActivateDownId | ImGuiID | None |  |
| NavActivatePressedId | ImGuiID | None |  |
| NavActivateFlags | ImGuiActivateFlags | None |  |
| NavFocusRoute | ImVector<ImGuiFocusScopeData> | None |  |
| NavHighlightActivatedId | ImGuiID | None |  |
| NavHighlightActivatedTimer | float | None |  |
| NavNextActivateId | ImGuiID | None |  |
| NavNextActivateFlags | ImGuiActivateFlags | None |  |
| NavInputSource | ImGuiInputSource | None |  |
| NavLastValidSelectionUserData | ImGuiSelectionUserData | None |  |
| NavIdIsAlive | bool | None |  |
| NavMousePosDirty | bool | None |  |
| NavDisableHighlight | bool | None |  |
| NavDisableMouseHover | bool | None |  |
| NavAnyRequest | bool | None |  |
| NavInitRequest | bool | None |  |
| NavInitRequestFromMove | bool | None |  |
| NavInitResult | ImGuiNavItemData | None |  |
| NavMoveSubmitted | bool | None |  |
| NavMoveScoringItems | bool | None |  |
| NavMoveForwardToNextFrame | bool | None |  |
| NavMoveFlags | ImGuiNavMoveFlags | None |  |
| NavMoveScrollFlags | ImGuiScrollFlags | None |  |
| NavMoveKeyMods | ImGuiKeyChord | None |  |
| NavMoveDir | ImGuiDir | None |  |
| NavMoveDirForDebug | ImGuiDir | None |  |
| NavMoveClipDir | ImGuiDir | None |  |
| NavScoringRect | ImRect | None |  |
| NavScoringNoClipRect | ImRect | None |  |
| NavScoringDebugCount | int | None |  |
| NavTabbingDir | int | None |  |
| NavTabbingCounter | int | None |  |
| NavMoveResultLocal | ImGuiNavItemData | None |  |
| NavMoveResultLocalVisible | ImGuiNavItemData | None |  |
| NavMoveResultOther | ImGuiNavItemData | None |  |
| NavTabbingResultFirst | ImGuiNavItemData | None |  |
| NavJustMovedFromFocusScopeId | ImGuiID | None |  |
| NavJustMovedToId | ImGuiID | None |  |
| NavJustMovedToFocusScopeId | ImGuiID | None |  |
| NavJustMovedToKeyMods | ImGuiKeyChord | None |  |
| NavJustMovedToIsTabbing | bool | None |  |
| NavJustMovedToHasSelectionData | bool | None |  |
| ConfigNavWindowingKeyNext | ImGuiKeyChord | None |  |
| ConfigNavWindowingKeyPrev | ImGuiKeyChord | None |  |
| NavWindowingTarget | ImGuiWindow* | None |  |
| NavWindowingTargetAnim | ImGuiWindow* | None |  |
| NavWindowingListWindow | ImGuiWindow* | None |  |
| NavWindowingTimer | float | None |  |
| NavWindowingHighlightAlpha | float | None |  |
| NavWindowingToggleLayer | bool | None |  |
| NavWindowingToggleKey | ImGuiKey | None |  |
| NavWindowingAccumDeltaPos | ImVec2 | None |  |
| NavWindowingAccumDeltaSize | ImVec2 | None |  |
| DimBgRatio | float | None |  |
| DragDropActive | bool | None |  |
| DragDropWithinSource | bool | None |  |
| DragDropWithinTarget | bool | None |  |
| DragDropSourceFlags | ImGuiDragDropFlags | None |  |
| DragDropSourceFrameCount | int | None |  |
| DragDropMouseButton | int | None |  |
| DragDropPayload | ImGuiPayload | None |  |
| DragDropTargetRect | ImRect | None |  |
| DragDropTargetClipRect | ImRect | None |  |
| DragDropTargetId | ImGuiID | None |  |
| DragDropAcceptFlags | ImGuiDragDropFlags | None |  |
| DragDropAcceptIdCurrRectSurface | float | None |  |
| DragDropAcceptIdCurr | ImGuiID | None |  |
| DragDropAcceptIdPrev | ImGuiID | None |  |
| DragDropAcceptFrameCount | int | None |  |
| DragDropHoldJustPressedId | ImGuiID | None |  |
| DragDropPayloadBufHeap | ImVector<unsigned char> | None |  |
| ClipperTempDataStacked | int | None |  |
| ClipperTempData | ImVector<ImGuiListClipperData> | None |  |
| CurrentTable | ImGuiTable* | None |  |
| DebugBreakInTable | ImGuiID | None |  |
| TablesTempDataStacked | int | None |  |
| TablesTempData | ImVector<ImGuiTableTempData> | None |  |
| Tables | ImPool<ImGuiTable> | None |  |
| TablesLastTimeActive | ImVector<float> | None |  |
| DrawChannelsTempMergeBuffer | ImVector<ImDrawChannel> | None |  |
| CurrentTabBar | ImGuiTabBar* | None |  |
| TabBars | ImPool<ImGuiTabBar> | None |  |
| CurrentTabBarStack | ImVector<ImGuiPtrOrIndex> | None |  |
| ShrinkWidthBuffer | ImVector<ImGuiShrinkWidthItem> | None |  |
| HoverItemDelayId | ImGuiID | None |  |
| HoverItemDelayIdPreviousFrame | ImGuiID | None |  |
| HoverItemDelayTimer | float | None |  |
| HoverItemDelayClearTimer | float | None |  |
| HoverItemUnlockedStationaryId | ImGuiID | None |  |
| HoverWindowUnlockedStationaryId | ImGuiID | None |  |
| MouseCursor | ImGuiMouseCursor | None |  |
| MouseStationaryTimer | float | None |  |
| MouseLastValidPos | ImVec2 | None |  |
| InputTextState | ImGuiInputTextState | None |  |
| InputTextDeactivatedState | ImGuiInputTextDeactivatedState | None |  |
| InputTextPasswordFont | ImFont | None |  |
| TempInputId | ImGuiID | None |  |
| DataTypeZeroValue | ImGuiDataTypeStorage | None |  |
| BeginMenuDepth | int | None |  |
| BeginComboDepth | int | None |  |
| ColorEditOptions | ImGuiColorEditFlags | None |  |
| ColorEditCurrentID | ImGuiID | None |  |
| ColorEditSavedID | ImGuiID | None |  |
| ColorEditSavedHue | float | None |  |
| ColorEditSavedSat | float | None |  |
| ColorEditSavedColor | ImU32 | None |  |
| ColorPickerRef | ImVec4 | None |  |
| ComboPreviewData | ImGuiComboPreviewData | None |  |
| WindowResizeBorderExpectedRect | ImRect | None |  |
| WindowResizeRelativeMode | bool | None |  |
| ScrollbarSeekMode | short | None |  |
| ScrollbarClickDeltaToGrabCenter | float | None |  |
| SliderGrabClickOffset | float | None |  |
| SliderCurrentAccum | float | None |  |
| SliderCurrentAccumDirty | bool | None |  |
| DragCurrentAccumDirty | bool | None |  |
| DragCurrentAccum | float | None |  |
| DragSpeedDefaultRatio | float | None |  |
| DisabledAlphaBackup | float | None |  |
| DisabledStackSize | short | None |  |
| LockMarkEdited | short | None |  |
| TooltipOverrideCount | short | None |  |
| ClipboardHandlerData | ImVector<char> | None |  |
| MenusIdSubmittedThisFrame | ImVector<ImGuiID> | None |  |
| TypingSelectState | ImGuiTypingSelectState | None |  |
| PlatformImeData | ImGuiPlatformImeData | None |  |
| PlatformImeDataPrev | ImGuiPlatformImeData | None |  |
| SettingsLoaded | bool | None |  |
| SettingsDirtyTimer | float | None |  |
| SettingsIniData | ImGuiTextBuffer | None |  |
| SettingsHandlers | ImVector<ImGuiSettingsHandler> | None |  |
| SettingsWindows | ImChunkStream<ImGuiWindowSettings> | None |  |
| SettingsTables | ImChunkStream<ImGuiTableSettings> | None |  |
| Hooks | ImVector<ImGuiContextHook> | None |  |
| HookIdNext | ImGuiID | None |  |
| LogEnabled | bool | None |  |
| LogType | ImGuiLogType | None |  |
| LogFile | ImFileHandle | None |  |
| LogBuffer | ImGuiTextBuffer | None |  |
| LogNextPrefix | char* | None |  |
| LogNextSuffix | char* | None |  |
| LogLinePosY | float | None |  |
| LogLineFirstItem | bool | None |  |
| LogDepthRef | int | None |  |
| LogDepthToExpand | int | None |  |
| LogDepthToExpandDefault | int | None |  |
| DebugLogFlags | ImGuiDebugLogFlags | None |  |
| DebugLogBuf | ImGuiTextBuffer | None |  |
| DebugLogIndex | ImGuiTextIndex | None |  |
| DebugLogAutoDisableFlags | ImGuiDebugLogFlags | None |  |
| DebugLogAutoDisableFrames | ImU8 | None |  |
| DebugLocateFrames | ImU8 | None |  |
| DebugBreakInLocateId | bool | None |  |
| DebugBreakKeyChord | ImGuiKeyChord | None |  |
| DebugBeginReturnValueCullDepth | ImS8 | None |  |
| DebugItemPickerActive | bool | None |  |
| DebugItemPickerMouseButton | ImU8 | None |  |
| DebugItemPickerBreakId | ImGuiID | None |  |
| DebugFlashStyleColorTime | float | None |  |
| DebugFlashStyleColorBackup | ImVec4 | None |  |
| DebugMetricsConfig | ImGuiMetricsConfig | None |  |
| DebugIDStackTool | ImGuiIDStackTool | None |  |
| DebugAllocInfo | ImGuiDebugAllocInfo | None |  |
| FramerateSecPerFrameIdx | int | None |  |
| FramerateSecPerFrameCount | int | None |  |
| FramerateSecPerFrameAccum | float | None |  |
| WantCaptureMouseNextFrame | int | None |  |
| WantCaptureKeyboardNextFrame | int | None |  |
| WantTextInputNextFrame | int | None |  |
| TempBuffer | ImVector<char> | None |  |

## ImGuiContextHook
**doc_id:** `component:ImGuiContextHook`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1906`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| HookId | ImGuiID | None |  |
| Type | ImGuiContextHookType | None |  |
| Owner | ImGuiID | None |  |
| Callback | ImGuiContextHookCallback | None |  |
| UserData | void* | None |  |

## ImGuiDataTypeInfo
**doc_id:** `component:ImGuiDataTypeInfo`
**Location:** `src/third_party/rlImGui/imgui_internal.h:822`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Size | size_t | None |  |
| Name | char* | None |  |
| PrintFmt | char* | None |  |
| ScanFmt | char* | None |  |

## ImGuiDataTypeStorage
**doc_id:** `component:ImGuiDataTypeStorage`
**Location:** `src/third_party/rlImGui/imgui_internal.h:816`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImGuiDataVarInfo
**doc_id:** `component:ImGuiDataVarInfo`
**Location:** `src/third_party/rlImGui/imgui_internal.h:808`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Type | ImGuiDataType | None |  |
| Count | ImU32 | None |  |
| Offset | ImU32 | None |  |

## ImGuiDebugAllocEntry
**doc_id:** `component:ImGuiDebugAllocEntry`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1841`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| FrameCount | int | None |  |
| AllocCount | ImS16 | None |  |
| FreeCount | ImS16 | None |  |

## ImGuiDebugAllocInfo
**doc_id:** `component:ImGuiDebugAllocInfo`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1848`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| TotalAllocCount | int | None |  |
| TotalFreeCount | int | None |  |
| LastEntriesIdx | ImS16 | None |  |

## ImGuiFocusScopeData
**doc_id:** `component:ImGuiFocusScopeData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1609`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ID | ImGuiID | None |  |
| WindowID | ImGuiID | None |  |

## ImGuiIDStackTool
**doc_id:** `component:ImGuiIDStackTool`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1887`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| LastActiveFrame | int | None |  |
| StackLevel | int | None |  |
| QueryId | ImGuiID | None |  |
| Results | ImVector<ImGuiStackLevelInfo> | None |  |
| CopyToClipboardOnCtrlC | bool | None |  |
| CopyToClipboardLastTime | float | None |  |

## ImGuiIO
**doc_id:** `component:ImGuiIO`
**Location:** `src/third_party/rlImGui/imgui.h:2152`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ConfigFlags | ImGuiConfigFlags | None |  |
| BackendFlags | ImGuiBackendFlags | None |  |
| DisplaySize | ImVec2 | None |  |
| DeltaTime | float | None |  |
| IniSavingRate | float | None |  |
| IniFilename | char* | None |  |
| LogFilename | char* | None |  |
| UserData | void* | None |  |
| FontGlobalScale | float | None |  |
| FontAllowUserScaling | bool | None |  |
| FontDefault | ImFont* | None |  |
| DisplayFramebufferScale | ImVec2 | None |  |
| MouseDrawCursor | bool | None |  |
| ConfigMacOSXBehaviors | bool | None |  |
| ConfigInputTrickleEventQueue | bool | None |  |
| ConfigInputTextCursorBlink | bool | None |  |
| ConfigInputTextEnterKeepActive | bool | None |  |
| ConfigDragClickToInputText | bool | None |  |
| ConfigWindowsResizeFromEdges | bool | None |  |
| ConfigWindowsMoveFromTitleBarOnly | bool | None |  |
| ConfigMemoryCompactTimer | float | None |  |
| MouseDoubleClickTime | float | None |  |
| MouseDoubleClickMaxDist | float | None |  |
| MouseDragThreshold | float | None |  |
| KeyRepeatDelay | float | None |  |
| KeyRepeatRate | float | None |  |
| ConfigDebugIsDebuggerPresent | bool | None |  |
| ConfigDebugBeginReturnValueOnce | bool | None |  |
| ConfigDebugBeginReturnValueLoop | bool | None |  |
| ConfigDebugIgnoreFocusLoss | bool | None |  |
| ConfigDebugIniSettings | bool | None |  |
| BackendPlatformName | char* | None |  |
| BackendRendererName | char* | None |  |
| BackendPlatformUserData | void* | None |  |
| BackendRendererUserData | void* | None |  |
| BackendLanguageUserData | void* | None |  |
| ClipboardUserData | void* | None |  |
| PlatformLocaleDecimalPoint | ImWchar | None |  |
| WantCaptureMouse | bool | None |  |
| WantCaptureKeyboard | bool | None |  |
| WantTextInput | bool | None |  |
| WantSetMousePos | bool | None |  |
| WantSaveIniSettings | bool | None |  |
| NavActive | bool | None |  |
| NavVisible | bool | None |  |
| Framerate | float | None |  |
| MetricsRenderVertices | int | None |  |
| MetricsRenderIndices | int | None |  |
| MetricsRenderWindows | int | None |  |
| MetricsActiveWindows | int | None |  |
| MouseDelta | ImVec2 | None |  |
| Ctx | ImGuiContext* | None |  |
| MousePos | ImVec2 | None |  |
| MouseWheel | float | None |  |
| MouseWheelH | float | None |  |
| MouseSource | ImGuiMouseSource | None |  |
| KeyCtrl | bool | None |  |
| KeyShift | bool | None |  |
| KeyAlt | bool | None |  |
| KeySuper | bool | None |  |
| KeyMods | ImGuiKeyChord | None |  |
| WantCaptureMouseUnlessPopupClose | bool | None |  |
| MousePosPrev | ImVec2 | None |  |
| MouseWheelRequestAxisSwap | bool | None |  |
| MouseCtrlLeftAsRightClick | bool | None |  |
| PenPressure | float | None |  |
| AppFocusLost | bool | None |  |
| AppAcceptingEvents | bool | None |  |
| BackendUsingLegacyKeyArrays | ImS8 | None |  |
| BackendUsingLegacyNavInputArray | bool | None |  |
| InputQueueSurrogate | ImWchar16 | None |  |
| InputQueueCharacters | ImVector<ImWchar> | None |  |

## ImGuiInputEvent
**doc_id:** `component:ImGuiInputEvent`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1390`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Type | ImGuiInputEventType | None |  |
| Source | ImGuiInputSource | None |  |
| EventId | ImU32 | None |  |
| MousePos | ImGuiInputEventMousePos | None |  |
| MouseWheel | ImGuiInputEventMouseWheel | None |  |
| MouseButton | ImGuiInputEventMouseButton | None |  |
| Key | ImGuiInputEventKey | None |  |
| Text | ImGuiInputEventText | None |  |
| AppFocused | ImGuiInputEventAppFocused | None |  |
| AddedByTestEngine | bool | None |  |

## ImGuiInputEventAppFocused
**doc_id:** `component:ImGuiInputEventAppFocused`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1388`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImGuiInputEventKey
**doc_id:** `component:ImGuiInputEventKey`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1386`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImGuiInputEventMouseButton
**doc_id:** `component:ImGuiInputEventMouseButton`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1385`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImGuiInputEventMousePos
**doc_id:** `component:ImGuiInputEventMousePos`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1383`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImGuiInputEventMouseWheel
**doc_id:** `component:ImGuiInputEventMouseWheel`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1384`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImGuiInputEventText
**doc_id:** `component:ImGuiInputEventText`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1387`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImGuiInputTextCallbackData
**doc_id:** `component:ImGuiInputTextCallbackData`
**Location:** `src/third_party/rlImGui/imgui.h:2359`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Ctx | ImGuiContext* | None |  |
| EventFlag | ImGuiInputTextFlags | None |  |
| Flags | ImGuiInputTextFlags | None |  |
| UserData | void* | None |  |
| EventChar | ImWchar | None |  |
| EventKey | ImGuiKey | None |  |
| Buf | char* | None |  |
| BufTextLen | int | None |  |
| BufSize | int | None |  |
| BufDirty | bool | None |  |
| CursorPos | int | None |  |
| SelectionStart | int | None |  |
| SelectionEnd | int | None |  |

## ImGuiKeyData
**doc_id:** `component:ImGuiKeyData`
**Location:** `src/third_party/rlImGui/imgui.h:2144`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Down | bool | None |  |
| DownDuration | float | None |  |
| DownDurationPrev | float | None |  |
| AnalogValue | float | None |  |

## ImGuiKeyOwnerData
**doc_id:** `component:ImGuiKeyOwnerData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1443`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| OwnerCurr | ImGuiID | None |  |
| OwnerNext | ImGuiID | None |  |
| LockThisFrame | bool | None |  |
| LockUntilRelease | bool | None |  |

## ImGuiKeyRoutingData
**doc_id:** `component:ImGuiKeyRoutingData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1417`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| NextEntryIndex | ImGuiKeyRoutingIndex | None |  |
| Mods | ImU16 | None |  |
| RoutingCurrScore | ImU8 | None |  |
| RoutingNextScore | ImU8 | None |  |
| RoutingCurr | ImGuiID | None |  |
| RoutingNext | ImGuiID | None |  |

## ImGuiKeyRoutingTable
**doc_id:** `component:ImGuiKeyRoutingTable`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1431`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Entries | ImVector<ImGuiKeyRoutingData> | None |  |
| EntriesNext | ImVector<ImGuiKeyRoutingData> | None |  |

## ImGuiLastItemData
**doc_id:** `component:ImGuiLastItemData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1238`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ID | ImGuiID | None |  |
| InFlags | ImGuiItemFlags | None |  |
| StatusFlags | ImGuiItemStatusFlags | None |  |
| Rect | ImRect | None |  |
| NavRect | ImRect | None |  |
| DisplayRect | ImRect | None |  |
| ClipRect | ImRect | None |  |
| Shortcut | ImGuiKeyChord | None |  |

## ImGuiListClipper
**doc_id:** `component:ImGuiListClipper`
**Location:** `src/third_party/rlImGui/imgui.h:2566`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Ctx | ImGuiContext* | None |  |
| DisplayStart | int | None |  |
| DisplayEnd | int | None |  |
| ItemsCount | int | None |  |
| ItemsHeight | float | None |  |
| StartPosY | float | None |  |
| TempData | void* | None |  |

## ImGuiListClipperData
**doc_id:** `component:ImGuiListClipperData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1513`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ListClipper | ImGuiListClipper* | None |  |
| LossynessOffset | float | None |  |
| StepNo | int | None |  |
| ItemsFrozen | int | None |  |
| Ranges | ImVector<ImGuiListClipperRange> | None |  |

## ImGuiListClipperRange
**doc_id:** `component:ImGuiListClipperRange`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1500`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Min | int | None |  |
| Max | int | None |  |
| PosToIndexConvert | bool | None |  |
| PosToIndexOffsetMin | ImS8 | None |  |
| PosToIndexOffsetMax | ImS8 | None |  |

## ImGuiLocEntry
**doc_id:** `component:ImGuiLocEntry`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1812`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Key | ImGuiLocKey | None |  |
| Text | char* | None |  |

## ImGuiMetricsConfig
**doc_id:** `component:ImGuiMetricsConfig`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1858`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ShowDebugLog | bool | false |  |
| ShowIDStackTool | bool | false |  |
| ShowWindowsRects | bool | false |  |
| ShowWindowsBeginOrder | bool | false |  |
| ShowTablesRects | bool | false |  |
| ShowDrawCmdMesh | bool | true |  |
| ShowDrawCmdBoundingBoxes | bool | true |  |
| ShowTextEncodingViewer | bool | false |  |
| ShowAtlasTintedWithTextColor | bool | false |  |
| ShowWindowsRectsType | int | -1 |  |
| ShowTablesRectsType | int | -1 |  |
| HighlightMonitorIdx | int | -1 |  |
| HighlightViewportID | ImGuiID | 0 |  |

## ImGuiNavItemData
**doc_id:** `component:ImGuiNavItemData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1592`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Window | ImGuiWindow* | None |  |
| ID | ImGuiID | None |  |
| FocusScopeId | ImGuiID | None |  |
| RectRel | ImRect | None |  |
| InFlags | ImGuiItemFlags | None |  |
| DistBox | float | None |  |
| DistCenter | float | None |  |
| DistAxial | float | None |  |
| SelectionUserData | ImGuiSelectionUserData | None |  |

## ImGuiNavTreeNodeData
**doc_id:** `component:ImGuiNavTreeNodeData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1256`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ID | ImGuiID | None |  |
| InFlags | ImGuiItemFlags | None |  |
| NavRect | ImRect | None |  |

## ImGuiNextItemData
**doc_id:** `component:ImGuiNextItemData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1220`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Flags | ImGuiNextItemDataFlags | None |  |
| ItemFlags | ImGuiItemFlags | None |  |
| SelectionUserData | ImGuiSelectionUserData | None |  |
| Width | float | None |  |
| Shortcut | ImGuiKeyChord | None |  |
| ShortcutFlags | ImGuiInputFlags | None |  |
| OpenVal | bool | None |  |
| OpenCond | ImU8 | None |  |
| RefVal | ImGuiDataTypeStorage | None |  |

## ImGuiNextWindowData
**doc_id:** `component:ImGuiNextWindowData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1183`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Flags | ImGuiNextWindowDataFlags | None |  |
| PosCond | ImGuiCond | None |  |
| SizeCond | ImGuiCond | None |  |
| CollapsedCond | ImGuiCond | None |  |
| PosVal | ImVec2 | None |  |
| PosPivotVal | ImVec2 | None |  |
| SizeVal | ImVec2 | None |  |
| ContentSizeVal | ImVec2 | None |  |
| ScrollVal | ImVec2 | None |  |
| ChildFlags | ImGuiChildFlags | None |  |
| CollapsedVal | bool | None |  |
| SizeConstraintRect | ImRect | None |  |
| SizeCallback | ImGuiSizeCallback | None |  |
| SizeCallbackUserData | void* | None |  |
| BgAlphaVal | float | None |  |
| MenuBarOffsetMinVal | ImVec2 | None |  |
| RefreshFlagsVal | ImGuiWindowRefreshFlags | None |  |

## ImGuiOldColumnData
**doc_id:** `component:ImGuiOldColumnData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1677`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| OffsetNorm | float | None |  |
| OffsetNormBeforeResize | float | None |  |
| Flags | ImGuiOldColumnFlags | None |  |
| ClipRect | ImRect | None |  |

## ImGuiOldColumns
**doc_id:** `component:ImGuiOldColumns`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1687`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ID | ImGuiID | None |  |
| Flags | ImGuiOldColumnFlags | None |  |
| IsFirstFrame | bool | None |  |
| IsBeingResized | bool | None |  |
| Current | int | None |  |
| Count | int | None |  |
| HostCursorPosY | float | None |  |
| HostCursorMaxPosX | float | None |  |
| HostInitialClipRect | ImRect | None |  |
| HostBackupClipRect | ImRect | None |  |
| HostBackupParentWorkRect | ImRect | None |  |
| Columns | ImVector<ImGuiOldColumnData> | None |  |
| Splitter | ImDrawListSplitter | None |  |

## ImGuiOnceUponAFrame
**doc_id:** `component:ImGuiOnceUponAFrame`
**Location:** `src/third_party/rlImGui/imgui.h:2437`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImGuiPayload
**doc_id:** `component:ImGuiPayload`
**Location:** `src/third_party/rlImGui/imgui.h:2402`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Data | void* | None |  |
| DataSize | int | None |  |
| SourceId | ImGuiID | None |  |
| SourceParentId | ImGuiID | None |  |
| DataFrameCount | int | None |  |
| Preview | bool | None |  |
| Delivery | bool | None |  |

## ImGuiPlatformImeData
**doc_id:** `component:ImGuiPlatformImeData`
**Location:** `src/third_party/rlImGui/imgui.h:3434`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| WantVisible | bool | None |  |
| InputPos | ImVec2 | None |  |
| InputLineHeight | float | None |  |

## ImGuiPopupData
**doc_id:** `component:ImGuiPopupData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1317`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| PopupId | ImGuiID | None |  |
| Window | ImGuiWindow* | None |  |
| RestoreNavWindow | ImGuiWindow* | None |  |
| ParentNavLayer | int | None |  |
| OpenFrameCount | int | None |  |
| OpenParentId | ImGuiID | None |  |
| OpenPopupPos | ImVec2 | None |  |
| OpenMousePos | ImVec2 | None |  |

## ImGuiPtrOrIndex
**doc_id:** `component:ImGuiPtrOrIndex`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1296`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Ptr | void* | None |  |
| Index | int | None |  |

## ImGuiSettingsHandler
**doc_id:** `component:ImGuiSettingsHandler`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1779`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| TypeName | char* | None |  |
| TypeHash | ImGuiID | None |  |
| UserData | void* | None |  |

## ImGuiShrinkWidthItem
**doc_id:** `component:ImGuiShrinkWidthItem`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1289`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Index | int | None |  |
| Width | float | None |  |
| InitialWidth | float | None |  |

## ImGuiSizeCallbackData
**doc_id:** `component:ImGuiSizeCallbackData`
**Location:** `src/third_party/rlImGui/imgui.h:2393`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| UserData | void* | None |  |
| Pos | ImVec2 | None |  |
| CurrentSize | ImVec2 | None |  |
| DesiredSize | ImVec2 | None |  |

## ImGuiStackLevelInfo
**doc_id:** `component:ImGuiStackLevelInfo`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1875`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ID | ImGuiID | None |  |
| QueryFrameCount | ImS8 | None |  |
| QuerySuccess | bool | None |  |

## ImGuiStorage
**doc_id:** `component:ImGuiStorage`
**Location:** `src/third_party/rlImGui/imgui.h:2509`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Data | ImVector<ImGuiStoragePair> | None |  |

## ImGuiStoragePair
**doc_id:** `component:ImGuiStoragePair`
**Location:** `src/third_party/rlImGui/imgui.h:2492`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| key | ImGuiID | None |  |

## ImGuiStyle
**doc_id:** `component:ImGuiStyle`
**Location:** `src/third_party/rlImGui/imgui.h:2070`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Alpha | float | None |  |
| DisabledAlpha | float | None |  |
| WindowPadding | ImVec2 | None |  |
| WindowRounding | float | None |  |
| WindowBorderSize | float | None |  |
| WindowMinSize | ImVec2 | None |  |
| WindowTitleAlign | ImVec2 | None |  |
| WindowMenuButtonPosition | ImGuiDir | None |  |
| ChildRounding | float | None |  |
| ChildBorderSize | float | None |  |
| PopupRounding | float | None |  |
| PopupBorderSize | float | None |  |
| FramePadding | ImVec2 | None |  |
| FrameRounding | float | None |  |
| FrameBorderSize | float | None |  |
| ItemSpacing | ImVec2 | None |  |
| ItemInnerSpacing | ImVec2 | None |  |
| CellPadding | ImVec2 | None |  |
| TouchExtraPadding | ImVec2 | None |  |
| IndentSpacing | float | None |  |
| ColumnsMinSpacing | float | None |  |
| ScrollbarSize | float | None |  |
| ScrollbarRounding | float | None |  |
| GrabMinSize | float | None |  |
| GrabRounding | float | None |  |
| LogSliderDeadzone | float | None |  |
| TabRounding | float | None |  |
| TabBorderSize | float | None |  |
| TabMinWidthForCloseButton | float | None |  |
| TabBarBorderSize | float | None |  |
| TableAngledHeadersAngle | float | None |  |
| TableAngledHeadersTextAlign | ImVec2 | None |  |
| ColorButtonPosition | ImGuiDir | None |  |
| ButtonTextAlign | ImVec2 | None |  |
| SelectableTextAlign | ImVec2 | None |  |
| SeparatorTextBorderSize | float | None |  |
| SeparatorTextAlign | ImVec2 | None |  |
| SeparatorTextPadding | ImVec2 | None |  |
| DisplayWindowPadding | ImVec2 | None |  |
| DisplaySafeAreaPadding | ImVec2 | None |  |
| MouseCursorScale | float | None |  |
| AntiAliasedLines | bool | None |  |
| AntiAliasedLinesUseTex | bool | None |  |
| AntiAliasedFill | bool | None |  |
| CurveTessellationTol | float | None |  |
| CircleTessellationMaxError | float | None |  |
| HoverStationaryDelay | float | None |  |
| HoverDelayShort | float | None |  |
| HoverDelayNormal | float | None |  |
| HoverFlagsForTooltipMouse | ImGuiHoveredFlags | None |  |
| HoverFlagsForTooltipNav | ImGuiHoveredFlags | None |  |

## ImGuiStyleMod
**doc_id:** `component:ImGuiStyleMod`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1040`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| VarIdx | ImGuiStyleVar | None |  |

## ImGuiTabItem
**doc_id:** `component:ImGuiTabItem`
**Location:** `src/third_party/rlImGui/imgui_internal.h:2665`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ID | ImGuiID | None |  |
| Flags | ImGuiTabItemFlags | None |  |
| LastFrameVisible | int | None |  |
| LastFrameSelected | int | None |  |
| Offset | float | None |  |
| Width | float | None |  |
| ContentWidth | float | None |  |
| RequestedWidth | float | None |  |
| NameOffset | ImS32 | None |  |
| BeginOrder | ImS16 | None |  |
| IndexDuringLayout | ImS16 | None |  |
| WantClose | bool | None |  |

## ImGuiTableCellData
**doc_id:** `component:ImGuiTableCellData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:2797`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| BgColor | ImU32 | None |  |
| Column | ImGuiTableColumnIdx | None |  |

## ImGuiTableColumn
**doc_id:** `component:ImGuiTableColumn`
**Location:** `src/third_party/rlImGui/imgui_internal.h:2738`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Flags | ImGuiTableColumnFlags | None |  |
| WidthGiven | float | None |  |
| MinX | float | None |  |
| MaxX | float | None |  |
| WidthRequest | float | None |  |
| WidthAuto | float | None |  |
| StretchWeight | float | None |  |
| InitStretchWeightOrWidth | float | None |  |
| ClipRect | ImRect | None |  |
| UserID | ImGuiID | None |  |
| WorkMinX | float | None |  |
| WorkMaxX | float | None |  |
| ItemWidth | float | None |  |
| ContentMaxXFrozen | float | None |  |
| ContentMaxXUnfrozen | float | None |  |
| ContentMaxXHeadersUsed | float | None |  |
| ContentMaxXHeadersIdeal | float | None |  |
| NameOffset | ImS16 | None |  |
| DisplayOrder | ImGuiTableColumnIdx | None |  |
| IndexWithinEnabledSet | ImGuiTableColumnIdx | None |  |
| PrevEnabledColumn | ImGuiTableColumnIdx | None |  |
| NextEnabledColumn | ImGuiTableColumnIdx | None |  |
| SortOrder | ImGuiTableColumnIdx | None |  |
| DrawChannelCurrent | ImGuiTableDrawChannelIdx | None |  |
| DrawChannelFrozen | ImGuiTableDrawChannelIdx | None |  |
| DrawChannelUnfrozen | ImGuiTableDrawChannelIdx | None |  |
| IsEnabled | bool | None |  |
| IsUserEnabled | bool | None |  |
| IsUserEnabledNextFrame | bool | None |  |
| IsVisibleX | bool | None |  |
| IsVisibleY | bool | None |  |
| IsRequestOutput | bool | None |  |
| IsSkipItems | bool | None |  |
| IsPreserveWidthAuto | bool | None |  |
| NavLayerCurrent | ImS8 | None |  |
| AutoFitQueue | ImU8 | None |  |
| CannotSkipItemsQueue | ImU8 | None |  |
| SortDirectionsAvailList | ImU8 | None |  |

## ImGuiTableColumnSettings
**doc_id:** `component:ImGuiTableColumnSettings`
**Location:** `src/third_party/rlImGui/imgui_internal.h:2976`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| WidthOrWeight | float | None |  |
| UserID | ImGuiID | None |  |
| Index | ImGuiTableColumnIdx | None |  |
| DisplayOrder | ImGuiTableColumnIdx | None |  |
| SortOrder | ImGuiTableColumnIdx | None |  |

## ImGuiTableColumnSortSpecs
**doc_id:** `component:ImGuiTableColumnSortSpecs`
**Location:** `src/third_party/rlImGui/imgui.h:1956`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ColumnUserID | ImGuiID | None |  |
| ColumnIndex | ImS16 | None |  |
| SortOrder | ImS16 | None |  |
| SortDirection | ImGuiSortDirection | None |  |

## ImGuiTableHeaderData
**doc_id:** `component:ImGuiTableHeaderData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:2806`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Index | ImGuiTableColumnIdx | None |  |
| TextColor | ImU32 | None |  |
| BgColor0 | ImU32 | None |  |
| BgColor1 | ImU32 | None |  |

## ImGuiTableInstanceData
**doc_id:** `component:ImGuiTableInstanceData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:2816`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| TableInstanceID | ImGuiID | None |  |
| LastOuterHeight | float | None |  |
| LastTopHeadersRowHeight | float | None |  |
| LastFrozenHeight | float | None |  |
| HoveredRowLast | int | None |  |
| HoveredRowNext | int | None |  |

## ImGuiTableSettings
**doc_id:** `component:ImGuiTableSettings`
**Location:** `src/third_party/rlImGui/imgui_internal.h:3000`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ID | ImGuiID | None |  |
| SaveFlags | ImGuiTableFlags | None |  |
| RefScale | float | None |  |
| ColumnsCount | ImGuiTableColumnIdx | None |  |
| ColumnsCountMax | ImGuiTableColumnIdx | None |  |
| WantApply | bool | None |  |

## ImGuiTableSortSpecs
**doc_id:** `component:ImGuiTableSortSpecs`
**Location:** `src/third_party/rlImGui/imgui.h:1946`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Specs | ImGuiTableColumnSortSpecs* | None |  |
| SpecsCount | int | None |  |
| SpecsDirty | bool | None |  |

## ImGuiTextBuffer
**doc_id:** `component:ImGuiTextBuffer`
**Location:** `src/third_party/rlImGui/imgui.h:2472`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Buf | ImVector<char> | None |  |

## ImGuiTextFilter
**doc_id:** `component:ImGuiTextFilter`
**Location:** `src/third_party/rlImGui/imgui.h:2445`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| b | char* | None |  |
| e | char* | None |  |
| CountGrep | int | None |  |

## ImGuiTextIndex
**doc_id:** `component:ImGuiTextIndex`
**Location:** `src/third_party/rlImGui/imgui_internal.h:728`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| LineOffsets | ImVector<int> | None |  |
| EndOffset | int | 0 |  |

## ImGuiViewport
**doc_id:** `component:ImGuiViewport`
**Location:** `src/third_party/rlImGui/imgui.h:3409`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ID | ImGuiID | None |  |
| Flags | ImGuiViewportFlags | None |  |
| Pos | ImVec2 | None |  |
| Size | ImVec2 | None |  |
| WorkPos | ImVec2 | None |  |
| WorkSize | ImVec2 | None |  |
| PlatformHandle | void* | None |  |
| PlatformHandleRaw | void* | None |  |

## ImGuiWindowSettings
**doc_id:** `component:ImGuiWindowSettings`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1765`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| ID | ImGuiID | None |  |
| Pos | ImVec2ih | None |  |
| Size | ImVec2ih | None |  |
| Collapsed | bool | None |  |
| IsChild | bool | None |  |
| WantApply | bool | None |  |
| WantDelete | bool | None |  |

## ImGuiWindowStackData
**doc_id:** `component:ImGuiWindowStackData`
**Location:** `src/third_party/rlImGui/imgui_internal.h:1281`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Window | ImGuiWindow* | None |  |
| ParentLastItemDataBackup | ImGuiLastItemData | None |  |
| StackSizesOnBegin | ImGuiStackSizes | None |  |
| DisabledOverrideReenable | bool | None |  |

## ImNewWrapper
**doc_id:** `component:ImNewWrapper`
**Location:** `src/third_party/rlImGui/imgui.h:1976`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImPool
**doc_id:** `component:ImPool`
**Location:** `src/third_party/rlImGui/imgui_internal.h:675`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Buf | ImVector<T> | None |  |
| Map | ImGuiStorage | None |  |
| FreeIdx | ImPoolIdx | None |  |
| AliveCount | ImPoolIdx | None |  |

## ImSpan
**doc_id:** `component:ImSpan`
**Location:** `src/third_party/rlImGui/imgui_internal.h:622`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Data | T* | None |  |
| DataEnd | T* | None |  |

## ImSpanAllocator
**doc_id:** `component:ImSpanAllocator`
**Location:** `src/third_party/rlImGui/imgui_internal.h:652`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| BasePtr | char* | None |  |
| CurrOff | int | None |  |
| CurrIdx | int | None |  |

## ImTextCustomization
**doc_id:** `component:ImTextCustomization`
**Location:** `src/third_party/rlImGui/imgui.h:2675`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| _RangeItem | struct | const char* PosStart, * PosStop;
        ImColor     TextColor, HighlightColor, UnderlineColor, StrikethroughColor, MaskColor;
        unsigned Flag;

        enum FLAG
        {
            TEXTCOLOR = 1,
            HIGHLIGHT = 1 << 1,
            UNDERLINE = 1 << 2,
            STRIKETHROUGH = 1 << 3,
            MASK = 1 << 4,
            DISABLED = 1 << 5 |  |
| _Ranges | ImVector<_RangeItem> | None |  |
| Text | bool | None |  |
| Disabled | bool | None |  |
| Highlight | bool | None |  |
| Underline | bool | None |  |
| Strikethrough | bool | None |  |
| Mask | bool | None |  |
| TextColor | ImU32 | None |  |
| HighlightColor | ImU32 | None |  |
| UnderlineColor | ImU32 | None |  |
| StrikethroughColor | ImU32 | None |  |
| MaskColor | ImU32 | None |  |
| s | Style | None |  |
| s | return | None |  |

## ImVec1
**doc_id:** `component:ImVec1`
**Location:** `src/third_party/rlImGui/imgui_internal.h:512`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| x | float | None |  |

## ImVec2
**doc_id:** `component:ImVec2`
**Location:** `src/third_party/rlImGui/imgui.h:279`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImVec2ih
**doc_id:** `component:ImVec2ih`
**Location:** `src/third_party/rlImGui/imgui_internal.h:520`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImVec4
**doc_id:** `component:ImVec4`
**Location:** `src/third_party/rlImGui/imgui.h:292`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## ImVector
**doc_id:** `component:ImVector`
**Location:** `src/third_party/rlImGui/imgui.h:1998`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| Size | int | None |  |
| Capacity | int | None |  |
| Data | T* | None |  |

## InputDef
**doc_id:** `component:InputDef`
**Location:** `src/systems/ui/ui_pack.hpp:51`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| normal | RegionDef | None |  |
| focus | std::optional<RegionDef> | None |  |

## LayoutMetrics
**doc_id:** `component:LayoutMetrics`
**Location:** `src/systems/ui/layout_metrics.hpp:17`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| padding | float | None |  |
| emboss | float | None |  |
| scale | float | None |  |
| globalScale | float | None |  |
| s | float | cfg.scale.value_or(1.0f) |  |
| gs | float | globals::getGlobalUIScaleFactor() |  |

## NinePatchGuides
**doc_id:** `component:NinePatchGuides`
**Location:** `src/systems/ui/editor/pack_editor.hpp:29`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| left | int | 8 |  |
| top | int | 8 |  |
| right | int | 8 |  |
| bottom | int | 8 |  |

## PackEditorState
**doc_id:** `component:PackEditorState`
**Location:** `src/systems/ui/editor/pack_editor.hpp:66`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| packName | std::string | None |  |
| atlasPath | std::string | None |  |
| atlas | Texture2D* | nullptr |  |
| workingPack | UIAssetPack | None |  |
| zoom | float | 1.0f |  |
| pan | Vector2 | 0, 0 |  |
| selection | AtlasSelection | None |  |
| editCtx | EditContext | None |  |
| isOpen | bool | false |  |
| showPreview | bool | true |  |
| statusMessage | std::string | None |  |

## ProgressBarDef
**doc_id:** `component:ProgressBarDef`
**Location:** `src/systems/ui/ui_pack.hpp:33`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| background | RegionDef | None |  |
| fill | RegionDef | None |  |

## RegionDef
**doc_id:** `component:RegionDef`
**Location:** `src/systems/ui/ui_pack.hpp:18`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| region | Rectangle | 0, 0, 0, 0 |  |
| ninePatch | std::optional<NPatchInfo> | None |  |
| scaleMode | SpriteScaleMode | SpriteScaleMode::Stretch |  |

## Scope
**doc_id:** `component:Scope`
**Location:** `src/systems/ui/ui_clip.hpp:10`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| endExclusive | size_t | None |  |
| z | int | None |  |
| hadMatrix | bool | false |  |

## ScreenSpaceCollisionMarker
**doc_id:** `component:ScreenSpaceCollisionMarker`
**Location:** `src/systems/collision/broad_phase.hpp:24`
**Lua Access:** `TBD (verify in bindings)`
**Notes:** Marker component for UI screen-space collision

**Fields:** None

## ScrollbarDef
**doc_id:** `component:ScrollbarDef`
**Location:** `src/systems/ui/ui_pack.hpp:39`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| track | RegionDef | None |  |
| thumb | RegionDef | None |  |

## SizingEntry
**doc_id:** `component:SizingEntry`
**Location:** `src/systems/ui/sizing_pass.hpp:27`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| entity | entt::entity | entt::null |  |
| parentRect | LocalTransform | None |  |
| forceRecalculate | bool | false |  |
| scale | std::optional<float> | None |  |

## SliderDef
**doc_id:** `component:SliderDef`
**Location:** `src/systems/ui/ui_pack.hpp:45`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| track | RegionDef | None |  |
| thumb | RegionDef | None |  |

## SpriteButtonConfig
**doc_id:** `component:SpriteButtonConfig`
**Location:** `src/systems/ui/ui_decoration.hpp:60`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| states | SpriteButtonStates | None |  |
| borders | SpritePanelBorders | None |  |
| baseSprite | std::string | None |  |
| autoFindStates | bool | false |  |

## SpriteButtonStates
**doc_id:** `component:SpriteButtonStates`
**Location:** `src/systems/ui/ui_decoration.hpp:53`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| normal | std::string | None |  |
| hover | std::string | None |  |
| pressed | std::string | None |  |
| disabled | std::string | None |  |

## SpritePanelBorders
**doc_id:** `component:SpritePanelBorders`
**Location:** `src/systems/ui/ui_decoration.hpp:46`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| left | int | 0 |  |
| top | int | 0 |  |
| right | int | 0 |  |
| bottom | int | 0 |  |

## TypeTraits
**doc_id:** `component:TypeTraits`
**Location:** `src/systems/ui/type_traits.hpp:15`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| t | return | = UITypeEnum::VERTICAL_CONTAINER ||
               t == UITypeEnum::ROOT ||
               t == UITypeEnum::SCROLL_PANE |  |
| t | return | = UITypeEnum::HORIZONTAL_CONTAINER |  |
| t | return | = UITypeEnum::RECT_SHAPE ||
               t == UITypeEnum::TEXT ||
               t == UITypeEnum::OBJECT ||
               t == UITypeEnum::INPUT_TEXT ||
               t == UITypeEnum::SLIDER_UI ||
               t == UITypeEnum::FILLER |  |
| t | return | = UITypeEnum::TEXT ||
               t == UITypeEnum::OBJECT |  |
| t | return | = UITypeEnum::TEXT ||
               t == UITypeEnum::INPUT_TEXT |  |
| t | return | = UITypeEnum::OBJECT ||
               t == UITypeEnum::RECT_SHAPE |  |
| t | return | = UITypeEnum::RECT_SHAPE ||
               t == UITypeEnum::TEXT ||
               t == UITypeEnum::INPUT_TEXT ||
               t == UITypeEnum::OBJECT ||
               t == UITypeEnum::SLIDER_UI |  |

## UIAssetPack
**doc_id:** `component:UIAssetPack`
**Location:** `src/systems/ui/ui_pack.hpp:57`
**Lua Access:** `TBD (verify in bindings)`
**Notes:** 7 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| name | std::string | None |  |
| atlasPath | std::string | None |  |
| panels | std::unordered_map<std::string, RegionDef> | None | complex |
| buttons | std::unordered_map<std::string, ButtonDef> | None | complex |
| progressBars | std::unordered_map<std::string, ProgressBarDef> | None | complex |
| scrollbars | std::unordered_map<std::string, ScrollbarDef> | None | complex |
| sliders | std::unordered_map<std::string, SliderDef> | None | complex |
| inputs | std::unordered_map<std::string, InputDef> | None | complex |
| icons | std::unordered_map<std::string, RegionDef> | None | complex |

## UIBoxComponent
**doc_id:** `component:UIBoxComponent`
**Location:** `src/systems/ui/ui_data.hpp:117`
**Lua Access:** `TBD (verify in bindings)`
**Notes:** Manually added: indented struct not captured by extractor

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| uiRoot | std::optional<entt::entity> | None | complex |
| drawLayers | std::map<int, entt::entity> | None | complex |
| onBoxResize | std::function<void(entt::entity)> | nullptr | complex |

**Gotchas:**
- Move `UIBoxComponent.uiRoot` with the entity Transform, then call `ui.box.RenewAlignment` to refresh layout.


## UIConfig
**doc_id:** `component:UIConfig`
**Location:** `src/systems/ui/ui_data.hpp:241`
**Lua Access:** `TBD (verify in bindings)`
**Notes:** Manually added: indented struct not captured by extractor

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| stylingType | UIStylingType | UIStylingType::ROUNDED_RECTANGLE |  |
| nPatchInfo | std::optional<NPatchInfo> | None | complex |
| nPatchSourceTexture | std::optional<Texture2D> | None | complex |
| spriteSourceTexture | std::optional<Texture2D*> | None | complex |
| spriteSourceRect | std::optional<Rectangle> | None | complex |
| spriteScaleMode | SpriteScaleMode | SpriteScaleMode::Stretch |  |
| decorations | std::optional<UIDecorations> | None | complex |
| id | std::optional<std::string> | None | complex |
| instanceType | std::optional<std::string> | None | complex |
| uiType | std::optional<UITypeEnum> | None | complex |
| drawLayer | std::optional<int> | None | complex |
| group | std::optional<std::string> | None | complex |
| groupParent | std::optional<entt::entity> | None | complex |
| offset | std::optional<Vector2> | None | complex |
| scale | std::optional<float> | 1.0f | complex |
| textSpacing | std::optional<float> | None | complex |
| fontSize | std::optional<float> | None | complex |
| fontName | std::optional<std::string> | None | complex |
| focusWithObject | std::optional<bool> | None | complex |
| refreshMovement | std::optional<bool> | None | complex |
| noMovementWhenDragged | bool | false |  |
| master | std::optional<entt::entity> | None | complex |
| parent | std::optional<entt::entity> | None | complex |
| object | std::optional<entt::entity> | None | complex |
| objectRecalculate | bool | false |  |
| alignmentFlags | std::optional<int> | None | complex |
| padding | std::optional<float> | None | complex |
| includeChildrenInShaderPass | bool | true |  |
| outlineThickness | std::optional<float> | None | complex |
| makeMovementDynamic | bool | false |  |
| shadow | bool | false |  |
| outlineShadow | bool | false |  |
| shadowColor | std::optional<Color> | None | complex |
| noFill | bool | false |  |
| pixelatedRectangle | bool | true |  |
| button_UIE | std::optional<entt::entity> | None | complex |
| disable_button | bool | false |  |
| progressBarFetchValueLambda | std::function<float(entt::entity)> | nullptr | complex |
| progressBar | bool | false |  |
| progressBarMaxValue | std::optional<float> | None | complex |
| ui_object_updated | bool | false |  |
| buttonDelayStart | std::optional<float> | None | complex |
| buttonDelay | std::optional<float> | None | complex |
| buttonDelayProgress | std::optional<float> | None | complex |
| buttonDelayEnd | std::optional<float> | None | complex |
| buttonClicked | bool | false |  |
| buttonDistance | std::optional<float> | None | complex |
| tooltip | std::optional<Tooltip> | None | complex |
| detailedTooltip | std::optional<Tooltip> | None | complex |
| onDemandTooltip | std::optional<Tooltip> | None | complex |
| hover | bool | false |  |
| force_focus | bool | false |  |
| dynamicMotion | std::optional<bool> | None | complex |
| choice | std::optional<bool> | None | complex |
| chosen | std::optional<bool> | None | complex |
| one_press | std::optional<bool> | None | complex |
| chosen_vert | std::optional<std::string> | None | complex |
| draw_after | bool | false |  |
| focusArgs | std::optional<FocusArgs> | None | complex |
| instaFunc | std::optional<bool> | None | complex |
| ref_entity | std::optional<entt::entity> | None | complex |
| ref_component | std::optional<std::string> | None | complex |
| ref_value | std::optional<std::string> | None | complex |
| prev_ref_value | std::optional<entt::meta_any> | None | complex |
| text | std::optional<std::string> | None | complex |
| language | std::optional<std::string> | None | complex |
| verticalText | std::optional<bool> | None | complex |
| hPopup | std::optional<entt::entity> | None | complex |
| dPopup | std::optional<entt::entity> | None | complex |
| hPopupConfig | std::shared_ptr<UIConfig> | None |  |
| dPopupConfig | std::shared_ptr<UIConfig> | None |  |
| nPatchTiling | std::optional<nine_patch::NPatchTiling> | None | complex |
| extend_up | std::optional<float> | None | complex |
| resolution | std::optional<float> | None | complex |
| emboss | std::optional<float> | None | complex |
| line_emboss | bool | false |  |
| mid | bool | false |  |
| noRole | std::optional<bool> | None | complex |
| role | std::optional<transform::InheritedProperties> | None | complex |
| isFiller | bool | false |  |
| flexWeight | float | 1.0f |  |
| maxFillSize | float | 0.0f |  |
| computedFillSize | float | 0.0f |  |
| Builder | struct | None |  |

## UIConfigBundle
**doc_id:** `component:UIConfigBundle`
**Location:** `src/systems/ui/core/ui_components.hpp:248`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| style | UIStyleConfig | None |  |
| layout | UILayoutConfig | None |  |
| interaction | UIInteractionConfig | None |  |
| content | UIContentConfig | None |  |

## UIContentConfig
**doc_id:** `component:UIContentConfig`
**Location:** `src/systems/ui/core/ui_components.hpp:206`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| text | std::optional<std::string> | None |  |
| language | std::optional<std::string> | None |  |
| verticalText | std::optional<bool> | None |  |
| textSpacing | std::optional<float> | None |  |
| fontSize | std::optional<float> | None |  |
| fontName | std::optional<std::string> | None |  |
| object | std::optional<entt::entity> | None |  |
| objectRecalculate | bool | false |  |
| ui_object_updated | bool | false |  |
| includeChildrenInShaderPass | bool | true |  |
| progressBar | bool | false |  |
| progressBarMaxValue | std::optional<float> | None |  |
| progressBarValueComponentName | std::optional<std::string> | None |  |
| progressBarValueFieldName | std::optional<std::string> | None |  |
| ref_entity | std::optional<entt::entity> | None |  |
| ref_component | std::optional<std::string> | None |  |
| ref_value | std::optional<std::string> | None |  |
| prev_ref_value | std::optional<entt::meta_any> | None |  |
| hPopup | std::optional<entt::entity> | None |  |
| dPopup | std::optional<entt::entity> | None |  |
| hPopupConfig | std::shared_ptr<UIConfig> | None |  |
| dPopupConfig | std::shared_ptr<UIConfig> | None |  |
| instanceType | std::optional<std::string> | None |  |

## UIDecoration
**doc_id:** `component:UIDecoration`
**Location:** `src/systems/ui/ui_decoration.hpp:21`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| spriteName | std::string | None |  |
| anchor | Anchor | Anchor::TopLeft |  |
| offset | Vector2 | 0.0f, 0.0f |  |
| opacity | float | 1.0f |  |
| flipX | bool | false |  |
| flipY | bool | false |  |
| rotation | float | 0.0f |  |
| scale | Vector2 | 1.0f, 1.0f |  |
| zOffset | int | 0 |  |
| tint | Color | WHITE |  |
| visible | bool | true |  |
| id | std::string | None |  |

## UIDecorations
**doc_id:** `component:UIDecorations`
**Location:** `src/systems/ui/ui_decoration.hpp:42`
**Lua Access:** `TBD (verify in bindings)`
**Notes:** 1 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| items | std::vector<UIDecoration> | None | complex |

## UIDrawContext
**doc_id:** `component:UIDrawContext`
**Location:** `src/systems/ui/handlers/handler_interface.hpp:24`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| layer | std::shared_ptr<layer::Layer> | None |  |
| zIndex | int | 0 |  |
| config | UIConfig* | nullptr |  |
| state | UIState* | nullptr |  |
| node | transform::GameObject* | nullptr |  |
| rectCache | RoundedRectangleVerticesCache* | nullptr |  |
| fontData | globals::FontData* | nullptr |  |
| actualX | float | 0, actualY = 0, actualW = 0, actualH = 0 |  |
| visualX | float | 0, visualY = 0, visualW = 0, visualH = 0 |  |
| visualScaleWithHoverAndMotion | float | 1.0f |  |
| visualR | float | 0 |  |
| rotationOffset | float | 0 |  |
| parallaxDist | float | 1.2f |  |
| buttonBeingPressed | bool | false |  |
| buttonActive | bool | true |  |

## UIElementCore
**doc_id:** `component:UIElementCore`
**Location:** `src/systems/ui/core/ui_components.hpp:69`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| type | UITypeEnum | UITypeEnum::NONE |  |
| uiBox | entt::entity | entt::null |  |
| id | std::string | None |  |
| treeOrder | int | 0 |  |

## UIInteractionConfig
**doc_id:** `component:UIInteractionConfig`
**Location:** `src/systems/ui/core/ui_components.hpp:152`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| canCollide | std::optional<bool> | None |  |
| collideable | std::optional<bool> | None |  |
| forceCollision | std::optional<bool> | None |  |
| hover | bool | false |  |
| button_UIE | std::optional<entt::entity> | None |  |
| disable_button | bool | false |  |
| buttonDelay | std::optional<float> | None |  |
| buttonDelayStart | std::optional<float> | None |  |
| buttonDelayEnd | std::optional<float> | None |  |
| buttonDelayProgress | std::optional<float> | None |  |
| buttonDistance | std::optional<float> | None |  |
| buttonClicked | bool | false |  |
| force_focus | bool | false |  |
| focusWithObject | std::optional<bool> | None |  |
| focusArgs | std::optional<FocusArgs> | None |  |
| tooltip | std::optional<Tooltip> | None |  |
| detailedTooltip | std::optional<Tooltip> | None |  |
| onDemandTooltip | std::optional<Tooltip> | None |  |
| instaFunc | std::optional<bool> | None |  |
| choice | std::optional<bool> | None |  |
| chosen | std::optional<bool> | None |  |
| one_press | std::optional<bool> | None |  |
| chosen_vert | std::optional<std::string> | None |  |
| group | std::optional<std::string> | None |  |
| groupParent | std::optional<entt::entity> | None |  |
| dynamicMotion | std::optional<bool> | None |  |
| makeMovementDynamic | bool | false |  |
| noMovementWhenDragged | bool | false |  |
| refreshMovement | std::optional<bool> | None |  |

## UILayoutConfig
**doc_id:** `component:UILayoutConfig`
**Location:** `src/systems/ui/core/ui_components.hpp:114`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| padding | std::optional<float> | None |  |
| extend_up | std::optional<float> | None |  |
| alignmentFlags | std::optional<int> | None |  |
| location_bond | std::optional<transform::InheritedProperties::Sync> | None |  |
| rotation_bond | std::optional<transform::InheritedProperties::Sync> | None |  |
| size_bond | std::optional<transform::InheritedProperties::Sync> | None |  |
| scale_bond | std::optional<transform::InheritedProperties::Sync> | None |  |
| offset | std::optional<Vector2> | None |  |
| scale | std::optional<float> | None |  |
| no_recalc | std::optional<bool> | None |  |
| non_recalc | std::optional<bool> | None |  |
| mid | bool | false |  |
| noRole | std::optional<bool> | None |  |
| role | std::optional<transform::InheritedProperties> | None |  |
| master | std::optional<entt::entity> | None |  |
| parent | std::optional<entt::entity> | None |  |
| drawLayer | std::optional<int> | None |  |
| draw_after | bool | false |  |

## UISpriteConfig
**doc_id:** `component:UISpriteConfig`
**Location:** `src/systems/ui/ui_decoration.hpp:15`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| sizingMode | UISizingMode | UISizingMode::FitContent |  |
| spriteWidth | int | 0 |  |
| spriteHeight | int | 0 |  |

## UIStyleConfig
**doc_id:** `component:UIStyleConfig`
**Location:** `src/systems/ui/core/ui_components.hpp:79`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| stylingType | UIStylingType | UIStylingType::ROUNDED_RECTANGLE |  |
| color | std::optional<Color> | None |  |
| outlineColor | std::optional<Color> | None |  |
| shadowColor | std::optional<Color> | None |  |
| progressBarEmptyColor | std::optional<Color> | None |  |
| progressBarFullColor | std::optional<Color> | None |  |
| outlineThickness | std::optional<float> | None |  |
| emboss | std::optional<float> | None |  |
| resolution | std::optional<float> | None |  |
| shadow | bool | false |  |
| outlineShadow | bool | false |  |
| noFill | bool | false |  |
| pixelatedRectangle | bool | true |  |
| line_emboss | bool | false |  |
| nPatchInfo | std::optional<NPatchInfo> | None |  |
| nPatchSourceTexture | std::optional<Texture2D> | None |  |
| nPatchTiling | std::optional<nine_patch::NPatchTiling> | None |  |
| spriteSourceTexture | std::optional<Texture2D*> | None |  |
| spriteSourceRect | std::optional<Rectangle> | None |  |
| spriteScaleMode | SpriteScaleMode | SpriteScaleMode::Stretch |  |

## stbrp_context
**doc_id:** `component:stbrp_context`
**Location:** `src/third_party/rlImGui/imstb_rectpack.h:185`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| width | int | None |  |
| height | int | None |  |
| align | int | None |  |
| init_mode | int | None |  |
| heuristic | int | None |  |
| num_nodes | int | None |  |

## stbrp_node
**doc_id:** `component:stbrp_node`
**Location:** `src/third_party/rlImGui/imstb_rectpack.h:179`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## stbrp_rect
**doc_id:** `component:stbrp_rect`
**Location:** `src/third_party/rlImGui/imstb_rectpack.h:119`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| id | int | None |  |
| was_packed | int | None |  |

## stbrp_rect
**doc_id:** `component:stbrp_rect`
**Location:** `src/third_party/rlImGui/imstb_truetype.h:3919`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## stbtt_fontinfo
**doc_id:** `component:stbtt_fontinfo`
**Location:** `src/third_party/rlImGui/imstb_truetype.h:718`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| userdata | void           * | None |  |
| fontstart | int | None |  |
| numGlyphs | int | None |  |
| index_map | int | None |  |
| indexToLocFormat | int | None |  |
| cff | stbtt__buf | None |  |
| charstrings | stbtt__buf | None |  |
| gsubrs | stbtt__buf | None |  |
| subrs | stbtt__buf | None |  |
| fontdicts | stbtt__buf | None |  |
| fdselect | stbtt__buf | None |  |

## stbtt_pack_context
**doc_id:** `component:stbtt_pack_context`
**Location:** `src/third_party/rlImGui/imstb_truetype.h:683`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| width | int | None |  |
| height | int | None |  |
| stride_in_bytes | int | None |  |
| padding | int | None |  |
| skip_missing | int | None |  |
