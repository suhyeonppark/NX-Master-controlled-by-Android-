import '../actions/action_ids.dart';
import '../actions/action_models.dart';
import '../models/macro_config.dart';

/// Factory macros returned on first run (before the user edits anything).
///
/// These keep the same ids/steps/delays as the original hard-coded macros so the
/// fixed buttons on the home/relay/IR screens (which reference these ids) keep
/// working. Only `system_on`/`system_off` are surfaced on the home screen by
/// default; the relay/IR "전체" macros are triggered from their own tabs.
List<MacroConfig> defaultMacros() => const [
      MacroConfig(
        id: ActionIds.systemOn,
        label: '전체 전원 ON',
        confirm: true,
        confirmMessage: '전체 전원을 켜시겠습니까?',
        showOnHome: true,
        steps: [MacroStep(ActionIds.seqAllOn, delayAfterMs: 0)],
      ),
      MacroConfig(
        id: ActionIds.systemOff,
        label: '전체 전원 OFF',
        confirm: true,
        confirmMessage: '전체 전원을 끄시겠습니까?',
        showOnHome: true,
        danger: true,
        steps: [MacroStep(ActionIds.seqAllOff, delayAfterMs: 0)],
      ),
      MacroConfig(
        id: ActionIds.seqAllOn,
        label: 'Relay 전체 ON',
        showOnHome: false,
        steps: [
          MacroStep(ActionIds.seq1On, delayAfterMs: 300),
          MacroStep(ActionIds.seq2On, delayAfterMs: 0),
        ],
      ),
      MacroConfig(
        id: ActionIds.seqAllOff,
        label: 'Relay 전체 OFF',
        confirm: true,
        confirmMessage: '전체 전원을 끄시겠습니까?',
        showOnHome: false,
        danger: true,
        steps: [
          MacroStep(ActionIds.seq2Off, delayAfterMs: 300),
          MacroStep(ActionIds.seq1Off, delayAfterMs: 0),
        ],
      ),
      MacroConfig(
        id: ActionIds.allDisplayOn,
        label: 'IR 전체 ON',
        showOnHome: false,
        steps: [
          MacroStep(ActionIds.tv1PowerOn, delayAfterMs: 400),
          MacroStep(ActionIds.tv2PowerOn, delayAfterMs: 400),
        ],
      ),
      MacroConfig(
        id: ActionIds.allDisplayOff,
        label: 'IR 전체 OFF',
        confirm: true,
        confirmMessage: 'TV 전체를 끄시겠습니까?',
        showOnHome: false,
        danger: true,
        steps: [
          MacroStep(ActionIds.tv1PowerOff, delayAfterMs: 400),
          MacroStep(ActionIds.tv2PowerOff, delayAfterMs: 400),
        ],
      ),
    ];
