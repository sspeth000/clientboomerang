# Client Boomerang

A small Roblox **client-side** script that creates a Boomerang Tool in the local player's Backpack.

## What it does

- Creates a Tool named `Local Boomerang`.
- Builds a simple boomerang-shaped handle from Parts.
- Adds the Tool to `Players.LocalPlayer.Backpack`.
- Removes an older copy first, so rerunning the script does not stack duplicates.
- Uses no RemoteEvents, RemoteFunctions, server scripts, or inventory APIs.

## Install in your own Roblox experience

1. Open Roblox Studio.
2. In Explorer, open `StarterPlayer > StarterPlayerScripts`.
3. Insert a **LocalScript**.
4. Copy the contents of [`Boomerang.client.lua`](./Boomerang.client.lua) into it.
5. Press **Play**. The tool should appear in your local hotbar/Backpack.

## Important limitation

This is intentionally local-only. The Tool is created by the client and is not granted by the server, saved to the player's account, or replicated as a legitimate inventory item. Other players and server-side game logic will not receive it. Use it in an experience you own or are authorized to test.

## Credits

The original repository credits Roblox's classic gear source as inspiration:
https://github.com/Roblox/gear/tree/main/src/gear/18479357
