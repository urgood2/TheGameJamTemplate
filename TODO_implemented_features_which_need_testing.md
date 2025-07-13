
## IMPLMENTED, needs testing.
- [ ] ldtk implementation needs testing

- [ ] How to instantiate some ui in place in an existing ui window? How to inject/ alter? -> https://chatgpt.com/share/685d3104-e724-800a-90d8-08ac15bd9bdc 

- [ ] need functionality to completely reset game state right from the game, via a debug menu, and reload script
- [ ]  Easy way to access text & elements on already created ui? -> I already have getUIEbyID, document it, also get a way to ensure I'm interacting with the text/animation object itself, rather than the object uielement that wraps it -> https://chatgpt.com/share/6860e021-29d4-800a-9b4e-aaa7bc0ed4ae
- how to update static ui text? (currently uses textGetter, just like dynamic text) -> but gotta store the raw text before processing. how to update it if tags were used with it? -> THis is the way: https://chatgpt.com/share/6860e5bf-fe44-800a-b927-e40546592bb3 -> document the use of the tag "elementID" with getTextFromString. For updating such multi-line tagged static ui, 1) just delete everything (including animations /etc ) and inject again with new definition when something changes.; 2) alternatively inject short text and attach a getter to it (static ui can also have getters, see: textGetter) 3) fetch the segment in question after it becomes a uielement through the id assigned via the raw text ("elementID") -> eg. [Warning!](background=yellow;elementID=warning_box) 
- [ ] How to do camera with layers? How to haveui both in the world space and screen space and handle proper collision order for both? -> https://chatgpt.com/share/68624700-963c-800a-b35e-53d2c4699da2 -> additional quadtree. needs to be implemented. 
