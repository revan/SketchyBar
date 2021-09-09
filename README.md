# SketchyBar
This is a rewrite of the spacebar project, which itself is a rewrite of the statusbar code from yabai.

Features:
* As many widgets as you like at any of the three positions: left, center, right
* The order of the widgets in the sketchybarrc file will be the order in which they show in the bar
* Associate widgets to certain displays or spaces, to show specific information on the relevant screens/displays
* The widgets are highly customizable with settings for different fonts, colors, icon paddings, label paddings, etc. for each individual element
* Draw arbitrary graphs in the bar with external data provider scripts that push the data into the graph
* Overlay as many graphs as wanted, like system cpu usage and user cpu usage in one figure
* Individual refresh frequencies for each widget
* Let items subscribe to system events (e.g. space changed, etc.) for their refresh action
* Create custom events and trigger them externaly
* "click" events for the widgets, where a script can be specified to run on a mouse click
* Cache the scripts in RAM to reduce I/O operations
* Offset the bar from its original location, rounded corners and background blur
* Batch configuration messages for easy configuration
* Performance friendly


## Description
This bar project aims to create a highly flexible, customizable and fast statusbar for users that like playing around with
shell scripts and want to make their statusbar show exactly the information they need for their workflow.

The configuration of the bar takes place in a confiuration file where almost everything can be configured.
Bascially, the bar itself is a rectangle that can hold arbitrarily many *items* and *components*, which can be configured to do awesome stuff.
An *item* will occupy a space in the bar and can be equipped to show an *icon* and a *label*. The *icon* and *label* can be changed through
*scripts* that can be attached to the *item*. It is also possible to *subscribe* and *item* to certain *events* for their *script* execution action,
which makes very powerful items possible. Additionally, an *item* can be assigned a *click_script*, which executes on a mouse click.
Furthermore, an *item* can be assigned to mission control spaces or displays, such that they only show on a certain space or display, which makes multi-desktop configuration
of the bar possible and opens the possibility to create individualized bar configuration on a per display and per space level.
These simple ingredients make *items* almost endlessly customizable and can be used to display arbitrary information and perform useful actions. For some examples see my sketchybarrc and
the plugins folder.

Some special features can not be accomplished with a simple *item*, this is where the *components* come into play. They basically are *items* with
extra steps. They contain all the properties a regular item does, but they can do specialized tasks a simple item can not. For example, there
is a *graph* component, which can be used to display graphs in the bar.

For more details on how the configuration works, see the Configuration section below.

This is my setup:
![](images/mySetup.png)
where I have my screens and a vim mode indicator on the left. Not shown is the high memory warning which shows the process that is using high system memory on demand.
In the center I have a spotify indicator (only when music is playing) and on the right I have (not shown) a high cpu process indicator, as well as a cpu graph, a github contribution counter, a new mail counter and the current date.

The cpu and memory indicators are only shown on the "code" screen and are not visible on the other screens.

## Installation
### Stable Version
```bash
brew tap FelixKratz/formulae
brew install sketchybar
```
Do not forget to copy the example configuration files to your home directory:
```bash
mkdir ~/.config/sketchybar
cp /usr/local/opt/sketchybar/share/sketchybar/examples/sketchybarrc ~/.config/sketchybar/sketchybarrc
mkdir ~/.config/sketchybar/plugins
cp -r /usr/local/opt/sketchybar/share/sketchybar/examples/plugins/ ~/.config/sketchybar/plugins
chmod +x ~/.config/sketchybar/plugins/*
```
and run the bar via
```bash
brew services start sketchybar
```

### Development Version
Clone the repo and in it run 
```bash
make install
```
This installs the app with my configuration preinstalled.

You can customize the configuration inside of $HOME/.config/sketchybar/sketchybarrc
and run the bar via
```bash
sketchybar
```
### Switching branches and uninstalling
You can always switch branches by removing the current installation and reinstalling the selected branch
To uninstall the development version perform
```bash
make uninstall
```
in the cloned repo.

To uninstall the brew version simply run
```bash
brew uninstall sketchybar
```

### Plugins and Fonts
If you want to use your own plugins, make sure that they are referenced in the rc with the correct path and that they are made executable via
```bash
chmod +x name/of/plugin.sh
```
Have a look at the [discussion](https://github.com/FelixKratz/SketchyBar/discussions/12) about plugins and share your own if you want to.
You should of course vet the code from all plugins before granting them the executable bit to make sure they are not harming your computer.

If you have problems with missing fonts you might need to install the Hack Nerd Font:
```bash
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
```

## Updating
Since this is a work-in-progress project, there might be big and radical changes along the way. You can update by pulling from master and in the
up to date repo folder run:
```bash
make update
```
or simply update via brew.
This will not touch your configuration and the plugins, so if there is a radical change to the source code you might need to
update those files too.

## Configuration
Below is a list of all possible commands you can currently use in the configuration file located in *~/.config/sketchybar/sketchybarrc*:

### Global configuration of the bar
```bash
sketchybar -m config <setting> <value>
```
or when you want to batch configurations:
```bash
sketchybar -m batch --config <setting>=<value> ... <setting>=<value>
```

where the settings currently are:
* *position*: *top* or *bottom*
* *height*: the height of the bar in pixels
* *margin*: the screen padding around the bar itself
* *y_offset*: the y-offset in pixels from the default position
* *corner_radius*: the corner radius of the bar itself
* *blur_radius*: the blur radius to be applied to the background of the bar itself
* *padding_left*: padding on the left before first item 
* *padding_right*: just as padding_right
* *bar_color*: the color of the bar itself
* *display*: on which display to show bar (*main* or *all*)

### Adding a simple menubar item (items will appear in the bar in the order they are added)
```bash
sketchybar -m add item <name> <position>
```
where the *name* should not contain whitespaces, it can be used to further configure the item, which is covered later.
The *position* is the placement in the bar and can be either *left*, *right* or *center*.

### Adding a component
```bash
sketchybar -m add component <type> <name> <position>
```
Components are essentially items, but with special properties. 
Currently there are the component *types*: 
* ~~*title*: Showing the current window title,~~ (DEPRECATED, see [this](https://github.com/FelixKratz/SketchyBar/discussions/12#discussioncomment-1215932))
* *graph*: showing a graph,
* *space*: representing a mission control space

### Changing the properties of an item
```bash
sketchybar -m set <name> <property> <value>
```
here batching is also possible with:
```bash
sketchybar -m batch --set <name> <property>=<value> ... <property>=<value>
```
where the *name* is used to target the item with this name.

An item always has the following structure in the bar:  <br>
|-icon_padding_left-|-icon-|-icon_padding_right-|-label_padding_left-|-label-|-label_padding_right-| <br>

A list of properties is listed below:
* *associated_space*: on which space to show this item (can be multiple, not specifying anything will show item on all screens)
* *associated_display*: on which displays to show this item (can be multiple, not specifying anything will show item on all displays)
 
* *label*: the label of the item
* *label_font*: the font for the label
* *label_color*: the color of the label
* *label_highlight_color*: the highlight color of the label (e.g. for active space icon)
* *label_padding_left*: left padding of label (default: 0)
* *label_padding_right*: right padding of label (default: 0)
* *icon_highlight*: wether the icon is highlighted with the *icon_highlight_color* (values: *on*, *off*, default: *off*)
 
* *icon*: the icon of the item
* *icon_font*: the font for the icon
* *icon_color*: the color of the icon
* *icon_highlight_color*: the highlight color of the icon (e.g. for active space icon)
* *icon_padding_left*: left padding of icon (default: 0)
* *icon_padding_right*: right padding of icon (default: 0)
* *label_highlight*: wether the label is highlighted with the *label_highlight_color* (values: *on*, *off*, default: *off*)
 
* *graph_color*: color of the associated graph
* *background_color*: Draws a rectangular background for this item in the given color
 
* *script*: a script to run every *update_freq* seconds
* *update_freq*: time in seconds between script executions
* *click_script*: script to run when left clicking on item
* *cache_scripts*: If the scripts should be cached in RAM or read from disc every time (values: *on*, *off*, default: *off*)
* *scripting*: If scripts should be executed (values: *on*, *off*, default: *on*)
* *drawing*: If the item should be drawn into the bar (values: *on*, *off*, default: *on*)
* *lazy*: Changes do not trigger a redraw of the bar, item is refreshed when the bar is redrawn anyways (values: *on*, *off*, default: *off*)

### Changing the default values for all further items
```bash
sketchybar -m default <property> <value>
```
batching is again possible via:
```bash
sketchybar -m batch --default <property>=<value> ... <property>=<value>
```
this currently works for the properties:
* *label_font*
* *label_color*
* *label_highlight_color*
* *label_padding_left*
* *label_padding_right*

* *icon_font*
* *icon_color*
* *icon_highlight_color*
* *icon_padding_left*
* *icon_padding_right*
* *background_color*
* *update_freq*
* *cache_scripts*
* *scripting*
* *drawing*

It is also possible to reset the defaults via the command
```bash
sketchybar -m default reset
```

### Subscribing items to system events for their script execution
```bash
sketchybar -m subscribe <name> <event> ... <event>
```
where the events are:
* *front_app_switched*: when frontmost application changes (not triggered if a different app of the same window is focused)
* ~~*window_focus*: when a window is focused~~ (DEPRECATED, see custom event section)
* *space_change*: when the space is changed
* *display_change*: when the display is changed
* ~~*title_change*: when the title of the window changes~~ (DEPRECATED, see custom event section)
* *system_woke*: when the system has awaken from sleep

### Creating custom events
This allows to define events which are triggered by a different application (see Trigger custom events). Items can also subscribe to these events for their script execution.
```bash
sketchybar -m add event <name> [optional: <NSDistributedNotificationName>]
```
Optional: You can hook the notifications sent to the NSDistributedNotificationCenter e.g.
the notification Spotify sends on track change: "com.spotify.client.PlaybackStateChanged"
to create more responsive items

### Triggering custom events
This triggers a custom event that has been added before
```bash
sketchybar -m trigger <event>
```
This could be used to link the powerful event system of yabai to sketchybar by triggering the custom action via a yabai event.

### Supplying data for graphs
```bash
sketchybar -m push <name> <data>
```
This pushes the data point into the graph with name *name*.

### Forcing all shell scripts to run and the bar to refresh
```bash
sketchybar -m update
```
### Completely remove an item
```bash
sketchybar -m remove item <name>
```
This also works for components, just reference it by name.

### Freeze and unfreeze the bar
```bash
sketchybar -m freeze <on/off>
```
This stops the redrawing of the bar entirely and "freezes" it. Can be used during initialization to
create a cleaner startup by freezing the bar at the beginning of the configuration and unfreezing it after the
setup is done.

## Scripting
The bar supports scripts where ever possible to make it as customizable and versatile as possible.
When an item invokes a script, the script has access to some environment variables, such as:
```bash
$NAME 
```
Which is the name of the item that has invoked the script.
The space component has an additional variable
```bash
$SELECTED
```
which has the value *true* if the associated space is selected and *false* if the selected space is not selected.
By default the space component invokes the script:
```bash
if [ "$SELECTED" = "true" ]; then 
  sketchybar -m set $NAME icon_highlight on 
else 
  sketchybar -m set $NAME icon_highlight off 
fi
```
which you can freely configure to your liking by supplying a different script to the space component.
For performance reasons the space script is only run on change.
I plan on increasing the available environment variables in scripting step by step but if you have a suggestion let me know in the issues.

## Credits
yabai,
spacebar,
reddit,
many more for the great code base and inspiration
