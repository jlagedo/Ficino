 Entitlements (manual in Xcode)

 User needs to add:
 - com.apple.security.network.client — MusicKit needs network access from sandbox
 - MusicKit capability — for catalog search

 Xcode Setup (manual)

 1. Add FicinoCore as local package dependency
 2. Link FicinoCore framework to Ficino target
 3. Add entitlements above