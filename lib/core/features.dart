/// Build-level feature switches.
///
/// Chess is currently withheld from the app — only Perfect Circle and
/// Impostor (pass & play + online) remain. The chess code still compiles
/// (it is simply unreachable), so flipping this back to `true` restores
/// chess everywhere: singleplayer, pass & play, the online lobby and the
/// Chess Stats tile on the profile.
const bool kChessEnabled = false;
