# ChannelResort
**Channel Resort addon**

Developed mainly for TBC Classic.

Ever have the following problem?:  
You set up your channels in a certain way (/1 = General, /2 = Trade, LookingForGroup is red and so on).
Then you log on your alt and do the same.  
Then you swap back to your main and suddenly /2 is LookingForGroup, /3 is Trade and General is red.

This addon allows you to store the order and colours of your channels and then restore it later.

**Commands:**  
Use /channelresort or /cr  
/cr: Do the sort.  
In the below commands: Use Global if you only want to set up once for all characters, Me for character specific, All for all characters.  
You can combine Global setup as a default and Me setup as an exception for the current character.  
Preferred Channel setup and Auto Join Channel setup has seperate Global/Me handling.  

/cr help: Prints the help  
/cr [global|me|all] clear: Forget all setup for non-specic, specific or clear all data.  
/cr reset = all clear.  
/cr [global|me] store: Take your current channel setup and save those as preferred channels.  
/cr [global|me] autojoin [toggle|on|off|clear|print(default)]: When sorting Autojoin makes you join channels you haven't joined yet.  
/cr print: Print the current setup.  
/cr eval: Checks if a Resort is needed. Like printed at login.

**Known issues:**
- I tried making it restore automatically on login. It will run the code and say it's done, but it won't have actually done anything.
Probably I'm triggering still slightly too early, so instead the addon does a check and tells you to resort when needed.
- It also rechecks when loading to another zone.
