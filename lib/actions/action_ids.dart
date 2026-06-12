/// Canonical list of every action_id the app knows about (spec §18).
///
/// Keep all ids here so they are never scattered as magic strings across the
/// UI. The UI references [ActionIds.xxx]; the [ActionRegistry] maps each id to
/// its concrete definition.
class ActionIds {
  ActionIds._();

  // Macros
  static const String systemOn = 'system_on';
  static const String systemOff = 'system_off';
  static const String allDisplayOn = 'all_display_on';
  static const String allDisplayOff = 'all_display_off';

  // Prompter TV IR
  static const String tv1PowerOn = 'tv1_power_on';
  static const String tv1PowerOff = 'tv1_power_off';

  // PGM TV IR
  static const String tv2PowerOn = 'tv2_power_on';
  static const String tv2PowerOff = 'tv2_power_off';

  // Power relays.
  //   relay 1 = audio power, relay 2 = video power
  //   latching: close = ON, open = OFF.
  static const String seqAllOn = 'seq_all_on';
  static const String seqAllOff = 'seq_all_off';
  static const String seq1On = 'seq1_on';
  static const String seq1Off = 'seq1_off';
  static const String seq2On = 'seq2_on';
  static const String seq2Off = 'seq2_off';

  // Wake-on-LAN. `wolAll` wakes every configured PC; `wol(pcId)` targets one.
  // These are generated from the PC list in settings, not the button set.
  static const String wolAll = 'wol_all';
  static String wol(String pcId) => 'wol_$pcId';
}
