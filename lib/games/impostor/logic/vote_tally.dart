/// Whether an accusation can be handed out from a vote tally.
///
/// [votesDescending] must already be sorted highest first and contain every
/// player, including those who drew no votes. [slots] is how many players the
/// accusation needs.
///
/// Returns true when the player taking the last slot is tied with the player
/// just outside it — votes alone then cannot say who is accused, and picking
/// by seat order would decide the round arbitrarily.
bool accusationIsTied({
  required List<int> votesDescending,
  required int slots,
}) {
  if (slots <= 0 || slots >= votesDescending.length) {
    return false;
  }

  return votesDescending[slots - 1] ==
      votesDescending[slots];
}
