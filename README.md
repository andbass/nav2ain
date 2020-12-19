# nav2ain
Garrysmod - Converts Source Engine navmeshes into AI node graphs to support HL2 npcs on (almost) every map

If your desired map comes with an AI nodegraph (`.ain` file) or has AI node entities within the map, there's no need to use this, but this addon can be useful
for maps that don't come bundled with AI nodes, such as maps imported from other Source games.

You can check if your current map has an AIN via the `ai_show_connect` concmd, which renders the links between nodes in the AIN via colored lines.

## How to use
1. Generate a navmesh
  * You can use the `nav_generate` command built in to the Source engine
  * This step is skipable if your map comes with a built in navmesh (CS maps tend to)
  * To check, use the `nav_edit 1` concmd
2. Convert it to an AI nodegraph (AIN)
  * Use the `nav2ain_convert` command
  * You can optionally mark walkable points using `nav2ain_mark_walkable`, in some case this can improve the graph quality
  * If you have dev mode on `developer 1`, the generated nodegraph will be visible ingame
3. Save it
  * Use the `nav2ain_save` command
  * The nodegraph will be in `$YOUR_GMOD_FOLDER/data/$MAP_NAME.ain.txt`
4. Copy it to the `maps/graph` folder
  * Be sure to remove the `.txt`
  * The Source engine tends to saves an empty nodegraph for maps without AI node entities, you can overwrite this empty nodegraph if you like
    (it might be worth double checking you don't already have a valid nodegraph first though via the `ai_show_connect` command)
 
Each command will print out the next steps to perform in the console for more details
