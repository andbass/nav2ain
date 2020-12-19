# nav2ain
Garrysmod - Converts Source Engine navmeshes into AI node graphs to support HL2 npcs on (almost) every map

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
 
Each command will print out the next steps to perform in the console for more details
