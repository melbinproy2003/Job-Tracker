import 'package:flutter/material.dart';

/// App-wide messenger so deep-link handlers can toast without a BuildContext.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
