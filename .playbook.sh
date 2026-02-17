sudo darwin-rebuild switch --flake .#pc-hylia
sudo nixos-rebuild switch --flake .#server-tenoko

#1Password
eval $(op signin)

#Keysync
keysync backup --config keysync.yaml --all
keysync sync --config keysync.yaml --all

#Remove all keys

gpgconf --kill gpg-agent
rm -rf ~/.gnupg
gpg --list-keys

#Keysync Restore:

keysync restore --config keysync.yaml --host pc-hylia
gpg --list-keys --keyid-format long --with-subkey-fingerprint

#If anything goes wrong:
#Change variables if need be

$<keypath>=~/Documents/keys_backup/gpg-backup.asc
$<trustpath>=~/Documents/keys_backup/gpg-trust.txt
gpg --import --import-options restore $<keypath>
gpg --import-ownertrust $<trustpath>


#Sops Encrypt
sops secrets/pc-hylia/secrets.yaml
