# PSYamlTUI


## To do


### UI
- [x] Once a valid non branch node is selected then we want to display a clean heading of the item that is being run, and then we want
- [x] -Timer switch on start-menu, when a function or script file is called should we have it wrapped in a start and stop stopwatch and cleanly display processing time. if function fails or is stopped via ctrl+c mid way through. proper variable cleanup when looping back through.

### UX
- [x] *before* yaml hook, hook contains a function that returns true or false, if the hook returns true we want to execute what is listed in the call. if the hook fails we do not want to execute the call. Example, if the main call function needs to have a check beforehand to see if we are successfully authenticated to an api, this can be execute in the before call.
- [ ] when a user runs a script or function and it finishes, should we allow any key hit to return to main menu or should we have a param that abstract that out, so if the users wants to assign one to ensure the output isnt easily skipped, we have that option

### Data Validation
- [x] switched to yaml file secondarys

### Docs 
 - [ ] Clean read me heading, gif, test coverage stuff.
 - [ ] Simple, intermediate, advanced used example menus
 - [ ] Contributing or commiting changes

### Build
- [x] We need to write tests for the core points of this module
- [ ] How do we actually want to handle versioning on the automated build????
- [ ] Automate full build pipeline via github actions 
- [ ] Publish to powershell gallery
