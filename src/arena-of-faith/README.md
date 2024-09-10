Arena of Faith's Guessing Game

Contract deployed to: https://explorer.immutable.com/address/0xcd115a5452D0F3b0d78B818a54a3F56084634d69


Transaction flow appears to be:

* Account with Manager role calls GuessingGameBase:A1_createGame to configure a new game.
* Many addresses call GuessingGameBase:playGames to bet on a set of games, option id for their expected winner, and an amount to wager on the winner. The total value sent with the transaction must equal the sum of all the amounts wagered.
* Account with Manager role calls GuessingGameBase:B1_setWinOption to announce the winning option id.
* Account with Manager role calls GuessingGameBase:C_enablePrizeWithdraw to allow withdrawal of prizes.
* Many addresses call GuessingGameBase:claimMyPrizes to claim their prizes.