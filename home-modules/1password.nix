#Does this work?
# { pkgs, ... }:
#
# {
#   home.packages = with pkgs; [ _1password-cli ];
#
#   # Create a directory for custom scripts
#   home.file.".config/1password/scripts" = {
#     recursive = true;
#     source = ./1password/scripts;
#   };
#
#   # Create the 1password check script
#   xdg.configFile._1password.text = ''
#     def check_1password_accounts [] {
#       # Define the accounts to check
#       let account1 = "account1"  # Replace with your actual account name
#       let account2 = "account2"  # Replace with your actual account name
#       
#       # Check if op command is available
#       if (which op | is-empty) {
#         print "1Password CLI (op) is not installed or not in PATH"
#         return
#       }
#       
#       # Get list of accounts
#       let accounts = (do {
#         op account list --format=json | from json
#       } | catch {
#         []  # Return empty list if command fails
#       })
#       
#       # Check if accounts exist
#       let account1_exists = ($accounts | any { |a| $a.shorthand == $account1 })
#       let account2_exists = ($accounts | any { |a| $a.shorthand == $account2 })
#       
#       # Prompt user if accounts don't exist
#       if (not $account1_exists) {
#         print $"Account ($account1) not found in 1Password"
#         print "To add this account, run: op account add --address <your-domain>.1password.com --email <your-email>"
#       }
#       
#       if (not $account2_exists) {
#         print $"Account ($account2) not found in 1Password"
#         print "To add this account, run: op account add --address <your-domain>.1password.com --email <your-email>"
#       }
#     }
#
#     # Run the check function
#     check_1password_accounts
#   '';
# }
