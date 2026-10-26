import 'lua_topic.dart';
import 'topics_01_start.dart';
import 'topics_02_values.dart';
import 'topics_03_numbers.dart';
import 'topics_04_strings.dart';
import 'topics_05_patterns.dart';
import 'topics_06_tables.dart';
import 'topics_07_tablelib.dart';
import 'topics_08_meta.dart';
import 'topics_09_flow.dart';
import 'topics_10_loops.dart';
import 'topics_11_functions.dart';
import 'topics_12_closures.dart';
import 'topics_13_errors.dart';
import 'topics_14_modules.dart';
import 'topics_15_math.dart';
import 'topics_16_strlib.dart';
import 'topics_17_osio.dart';
import 'topics_18_utf8.dart';
import 'topics_19_coroutines.dart';
import 'topics_20_oop.dart';
import 'topics_21_lua54.dart';
import 'topics_22_debug.dart';
import 'topics_23_project.dart';
import 'topics_24_practice.dart';

/// Every authored Lua topic, in reading order.
///
/// Part files keep the corpus reviewable; the generator and verifier consume
/// this single list so ordering and ids stay in one place.
const List<LuaTopic> luaTopics = [
  ...topicsStart,
  ...topicsValues,
  ...topicsNumbers,
  ...topicsStrings,
  ...topicsPatterns,
  ...topicsTables,
  ...topicsTableLib,
  ...topicsMeta,
  ...topicsFlow,
  ...topicsLoops,
  ...topicsFunctions,
  ...topicsClosures,
  ...topicsErrors,
  ...topicsModules,
  ...topicsMath,
  ...topicsStrlib,
  ...topicsOsIo,
  ...topicsUtf8,
  ...topicsCoroutines,
  ...topicsOop,
  ...topicsLua54,
  ...topicsDebug,
  ...topicsProject,
  ...topicsPractice,
];
