# Zombie-Reloaded-MoZiLoR Edition

My version of CS:GO Zombie Reloaded based on Anubis's version: https://github.com/Stewart-Anubis/Sm-Zombiereloaded-3-Franug-Anubis-Edition

This version is a fully ready to use version, all you need to do is put the files on your server, change a few things and you have your own zombie mod server with a lot of plugins already installed.
My version is meant to emulate Zombie Mod as it was back in the golden age of Counter-Strike:Source Zombie Mod, with knockback when shooting zombies and the capacity to build propper barricades using props/objects.

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Drag and drop all files and folders in the csgo folder ( except "readme" ).

Things you need to change to get your server started:
-Server.cfg ( cfg folder )
   .Server name
   .Rcon password
   .( Avoid changing too much of the rest because some of the commands are used to fix bugs/issues )

-admins.cfg and admins_simple ( addons/sourcemod/configs )
   .Add your own admins, moderators and VIPs.

-hextags.cfg ( addons/sourcemod/configs )
   .Admins, mods, VIPs and players spending a lot of time on the server have access to special skins, chat colors and tags, you can customize your own there or leave it as is.

-advertisements.txt ( addons/sourcemod/configs )
   .Customize your own automatic ads/chat messages there.


-sourcemod.cfg ( cfg/sourcemod )
    .You can change the following values to choose how easy or hard objects will be moved when you shoot at them or press the "use" key on them.
sm_cvar sv_pushaway_force 32000 - 29000
sm_cvar sv_pushaway_max_force 750 - 600

Zombies Knockback ( how much a zombie is pushed back when you shoot him ) has been balanced so that every weapon is viable, however if you wish to change the knockback, you can do it in the following files located in ( addons/sourcemod/configs/zr ):

-hitgroups.txt
-playerclasses.txt
-weapons.txt

Although I recommend avoiding to change things as much as possible.


I made my own maps ( curently 10 of them ) which are adapted to the different settings, you can download the here:

https://gamebanana.com/members/1678108
