#include "sea80.h"

/****************************************************
Write a simple version of hangman, in which the user
enters the word he'll "guess", and then the user gets
to start guessing letters. After each guess, the word
is printed out with *s instead of unguessed letters.
 ****************************************************/
char answer[64];
uint8_t mask[64];

int main() {
  // Get word to guess
  print("Type het woord: ");
  readline(answer,64);
  printline();
  clearscreen();

  // Set the mask array - mask[i] is true if the
  // character s[i] has been guessed.  The mask
  // must be allocated, and initialized to all false
  uint8_t N = strlen(answer);
  for (int i = 0; i < N; ++i) {
    mask[i] = 0;
  }

  // Loop over each round of guessing
  unsigned char gameover = 0;
  unsigned char attempts = 0;
  while (!gameover) {
    attempts++;
    // Print word with *s for unguessed letters
    print("Het woord is : ");
    for (int j = 0; j < N; ++j) {
      if (mask[j] == 1) {
        putc(answer[j]);
      } else {
        print("*");
      }
    }
    printline();

    // Get player's next guess
    char guess;
    print("Letter? ");
    guess = getc();

    // Mark true all mask positions corresponding to guess
    for (int k = 0; k < N; ++k) {
      if (answer[k] == guess) {
        mask[k] = 1;
      }
    }

    // Determine whether the player has won!
    gameover = 1;
    for (int m = 0; m < N; ++m) {
      if (!mask[m]) {
        gameover = 0;
        break;
      }
    }
  }

  char buf[5];
  // Print victory message!
  print("\r\n\x02 Gewonnen in ");
  itoa(attempts,buf);
  print(buf);
  print(" keer! Het woord is \"");
  print(answer);
  print("\".\r\n");

  return 0;
}