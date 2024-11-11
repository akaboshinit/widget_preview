// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';

/// Handles forwarding virtual keypress events to active text input clients.
class PreviewTextInput with TextInputControl {
  /// The current state of the text input client.
  TextEditingValue _current = TextEditingValue.empty;

  /// The currently focused text client handling text input.
  ///
  /// Currently only used to determine the [TextInputAction] to perform when
  /// the user presses 'enter'.
  TextInputClient? _currentClient;

  /// Configuration details for the currently focused text client handling text
  /// input.
  ///
  /// Currently only used to determine the [TextInputAction] to perform when
  /// the user presses 'enter'.
  TextInputConfiguration? _currentConfiguration;

  /// Registers this instance as the default [TextInputControl] handler with
  /// [TextInput].
  ///
  /// Allows for this instance to receive state updates related to the
  /// currently active text input widget.
  void register() {
    TextInput.setInputControl(this);
  }

  /// Restores the default [TextInputControl] handler with [TextInput].
  void unregister() => TextInput.restorePlatformInputControl();

  /// Requests the text input control to attach to the given input client.
  ///
  /// This method is called when a text input client is attached. The input
  /// control should update its configuration to match the client's
  /// configuration.
  @override
  void attach(TextInputClient client, TextInputConfiguration configuration) {
    _currentClient = client;
    _currentConfiguration = configuration;
  }

  /// Requests the text input control to detach from the given input client.
  ///
  /// This method is called when a text input client is detached. The input
  /// control should release any resources allocated for the client.
  @override
  void detach(TextInputClient client) {
    _currentClient = null;
    _currentConfiguration = null;
  }

  /// Informs the text input control about input configuration changes.
  ///
  /// This method is called when the configuration of the attached input client
  /// has changed.
  @override
  void updateConfig(TextInputConfiguration configuration) {
    _currentConfiguration = configuration;
  }

  /// Informs the text input control about editing state changes.
  ///
  /// This method is called when the editing state of the attached input client
  /// has changed.
  @override
  void setEditingState(TextEditingValue value) {
    _current = value;
  }

  void _updateEditingValue(TextEditingValue value) {
    _current = value;
    TextInput.updateEditingValue(_current);
  }

  /// Replaces the content of [replacementRange] with [char].
  ///
  /// If [replacementRange] is collapsed, [char] is simply inserted at the
  /// cursor location specified by [replacementRange].
  ///
  /// Otherwise, the substring covered by [replacementRange] is replaced with
  /// [char].
  String _insertOrReplaceText(TextRange replacementRange, [String char = '']) {
    final prefix = replacementRange.textBefore(_current.text);
    final suffix = replacementRange.textAfter(_current.text);
    return (StringBuffer()..writeAll([prefix, char, suffix])).toString();
  }

  void _moveCursorPosition({required int updatedPosition}) {
    _updateEditingValue(
      _current.copyWith(
        selection: TextSelection.collapsed(offset: updatedPosition),
      ),
    );
  }

  /// Inserts [char] at the current [TextSelection].
  void pushCharacter(String char) {
    _updateEditingValue(
      _current.copyWith(
        text: _insertOrReplaceText(_current.selection, char),
        selection: TextSelection.collapsed(
          offset: _current.selection.baseOffset + 1,
        ),
      ),
    );
  }

  /// Deletes the characters covered by the current [TextSelection].
  ///
  /// If the [TextSelection] is collapsed, the character immediately preceeding
  /// the cursor position represented by [TextSelection] is deleted.
  void backspace() {
    final selection = _current.selection;
    if (_current.text.isEmpty || selection.baseOffset == 0) {
      // Nothing to update.
      return;
    }
    // If we're deleting a range of characters we don't need to update the
    // cursor position.
    final updatedBaseOffset =
        selection.baseOffset - (selection.isCollapsed ? 1 : 0);
    assert(updatedBaseOffset >= 0);
    _updateEditingValue(
      _current.copyWith(
        text: _insertOrReplaceText(
          selection.copyWith(baseOffset: updatedBaseOffset),
        ),
        selection: TextSelection.collapsed(offset: updatedBaseOffset),
      ),
    );
  }

  /// Move the cursor to the left.
  ///
  /// If the [TextSelection] is collapsed, the cursor is moved one position to
  /// the left.
  ///
  /// Otherwise, if [TextSelection] covers a range, the cursor is moved to the
  /// beginning of the selection.
  void arrowLeft() {
    final selection = _current.selection;
    final updatedPosition =
        selection.baseOffset - (selection.isCollapsed ? 1 : 0);
    _moveCursorPosition(updatedPosition: updatedPosition);
  }

  /// Move the cursor to the right.
  ///
  /// If the [TextSelection] is collapsed, the cursor is moved one position to
  /// the right.
  ///
  /// Otherwise, if [TextSelection] covers a range, the cursor is moved to the
  /// end of the selection.
  void arrowRight() {
    final selection = _current.selection;
    final updatedPosition =
        selection.baseOffset + (selection.isCollapsed ? 1 : 0);
    _moveCursorPosition(updatedPosition: updatedPosition);
  }

  /// Move the cursor to the beginning of the text field.
  void home() {
    final minPos =
        !_current.composing.isCollapsed ? _current.composing.start : 0;
    _moveCursorPosition(updatedPosition: minPos);
  }

  /// Move the cursor to the end of the text field.
  void end() {
    final maxPos = !_current.composing.isCollapsed
        ? _current.composing.end
        : _current.text.length;
    _moveCursorPosition(updatedPosition: maxPos);
  }

  /// Perform the input action associated with the current [TextInputClient].
  void enter() {
    _currentClient!.performAction(_currentConfiguration!.inputAction);
  }
}
