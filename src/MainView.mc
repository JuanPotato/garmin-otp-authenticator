using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

using TextInput;

var _error = "";
var _errorTicks = 0;

function displayError(str) {
  _error = str;
  _errorTicks = 50; // ~ 5 sec with the 100ms refresh (see Timer below)
}

function clearError() {
  _error = "";
  _errorTicks = 0;
}

class MainView extends WatchUi.View {
  var timer_;
  function initialize() {
    View.initialize();
    timer_ = new Timer.Timer();
  }

  function onShow() { timer_.start(method( : update), 100, true); }

  function onHide() {
    timer_.stop();
  }

  function update() {
    var provider = currentProvider();
    try {
      if (provider != null) {
        provider.update();
      }
    } catch (exception) {
      var msg = exception.getErrorMessage();
      log(ERROR, msg);
      exception.printStackTrace();
      displayError(msg);
    }
    WatchUi.requestUpdate();
  }

  function onUpdate(dc) {
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    dc.clear();
    var provider = currentProvider();
    if (provider == null) {
      dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM,
                  "Tap to start",
                  Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
      return;
    }
    // Use number font if possible
    var codeColor = Graphics.COLOR_WHITE;
    var codeFont = Graphics.FONT_NUMBER_HOT;
    var codeHeight = dc.getFontHeight(codeFont);
    switch (provider) {
    // NOTE(SN): This case deliberately falls-through
    case instanceof SteamGuardProvider:
      codeFont = Graphics.FONT_LARGE;
      codeHeight = dc.getFontHeight(codeFont);
    case instanceof TimeBasedProvider:
      // Provider name
      drawAboveCode(dc, codeHeight, Graphics.FONT_MEDIUM, provider.name_);
      // Colored OTP code depending on countdown
      var delta = provider.next_ - Time.now().value();
      if (delta > 15) {
        codeColor = Graphics.COLOR_GREEN;
      } else if (delta > 5) {
        codeColor = Graphics.COLOR_ORANGE;
      } else {
        codeColor = Graphics.COLOR_RED;
      }
      drawCode(dc, codeColor, codeFont, provider.code_);
      // Countdown text
      drawBelowCode(dc, codeHeight, Graphics.FONT_NUMBER_MILD, delta);
      break;
    case instanceof CounterBasedProvider:
      // Provider name
      drawAboveCode(dc, codeHeight, Graphics.FONT_MEDIUM, provider.name_);
      drawCode(dc, codeColor, codeFont, provider.code_);
      // Instructions
      drawBelowCode(dc, codeHeight, Graphics.FONT_SMALL,
                    "Press ENTER\nfor next code");
      break;
    }
    if (_errorTicks > 0) {
      _errorTicks--;
      dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
      dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL,
                  _error,
                  Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
  }

  function drawAboveCode(dc, codeHeight, font, text) {
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
    var fh = dc.getFontHeight(font);
    dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - codeHeight / 2 - fh,
                font, text, Graphics.TEXT_JUSTIFY_CENTER);
  }

  function drawCode(dc, codeColor, codeFont, code) {
    dc.setColor(codeColor, Graphics.COLOR_BLACK);
    dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, codeFont, code,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
  }

  function drawBelowCode(dc, codeHeight, font, text) {
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
    dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 + codeHeight / 2,
                font, text, Graphics.TEXT_JUSTIFY_CENTER);
  }
}

class MainViewDelegate extends WatchUi.BehaviorDelegate {
  function initialize() { BehaviorDelegate.initialize(); }

  function onKey(event) {
    var key = event.getKey();
    if (key == KEY_MENU) {
      var provider = currentProvider();
      switch (provider) {
      case instanceof CounterBasedProvider:
        provider.next();
        WatchUi.requestUpdate();
        return true;
      }
    }
    BehaviorDelegate.onKey(event);
  }

  function onSelect() {
    if (_providers.size() == 0) {
      var view = new TextInput.TextInputView("Enter name", Alphabet.ALPHANUM);
      WatchUi.pushView(view, new NameInputDelegate(view), WatchUi.SLIDE_RIGHT);
    } else {
      var menu = new Menu.MenuView({ :title => "OTP Authenticator" });
      menu.addItem(new Menu.MenuItem("Select entry", null, :select_entry, null));
      menu.addItem(new Menu.MenuItem("New entry", null, :new_entry, null));
      menu.addItem(new Menu.MenuItem("Delete entry", null, :delete_entry, null));
      menu.addItem(new Menu.MenuItem("Delete all entries", null, :delete_all, null));
      menu.addItem(new Menu.MenuItem("Export", "to settings", :export_providers, null));
      menu.addItem(new Menu.MenuItem("Import", "from settings", :import_providers, null));
      WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_LEFT);
    }
  }
}

class MainMenuDelegate extends Menu.MenuDelegate {
  function initialize() { Menu.MenuDelegate.initialize(); }

  function onMenuItem(identifier) {
    switch (identifier) {
    case :select_entry:
      var selectMenu = new Menu.MenuView({ :title => "Select" });
      for (var i = 0; i < _providers.size(); i++) {
        selectMenu.addItem(new Menu.MenuItem(_providers[i].name_, null, i, null));
      }
      Menu.switchTo(selectMenu, new SelectMenuDelegate(), WatchUi.SLIDE_LEFT);
      return true; // don't pop view
    case :new_entry:
      var view = new TextInput.TextInputView("Enter name", Alphabet.ALPHANUM);
      WatchUi.switchToView(view, new NameInputDelegate(view), WatchUi.SLIDE_RIGHT);
      return true; // don't pop view
    case :delete_entry:
      var deleteMenu = new Menu.MenuView({ :title => "Delete" });
      for (var i = 0; i < _providers.size(); i++) {
        deleteMenu.addItem(new Menu.MenuItem(_providers[i].name_, null, _providers[i], null));
      }
      Menu.switchTo(deleteMenu, new DeleteMenuDelegate(), WatchUi.SLIDE_LEFT);
      return true; // don't pop view
    case :delete_all:
      WatchUi.pushView(new WatchUi.Confirmation("Really delete?"),
                       new DeleteAllConfirmationDelegate(), WatchUi.SLIDE_LEFT);
      return true; // don't pop view
    case :export_providers:
      exportToSettings();
      break;
    case :import_providers:
      importFromSettings();
      saveProviders();
      break;
    }
    return false;
  }
}

class SelectMenuDelegate extends Menu.MenuDelegate {
  function initialize() { Menu.MenuDelegate.initialize(); }

  function onMenuItem(identifier) {
    _currentIndex = identifier;
    logf(DEBUG, "setting current index $1$", [_currentIndex]);
    saveProviders();
    clearError();
  }
}

class DeleteMenuDelegate extends Menu.MenuDelegate {
  function initialize() { Menu.MenuDelegate.initialize(); }

  function onMenuItem(identifier) {
    var provider = currentProvider();
    if (provider != null && provider == identifier) {
      _currentIndex = 0;
    }
    _providers.remove(identifier);
    saveProviders();
  }
}

class DeleteAllConfirmationDelegate extends WatchUi.ConfirmationDelegate {
  function initialize() { WatchUi.ConfirmationDelegate.initialize(); }

  function onResponse(response) {
    switch (response) {
      case WatchUi.CONFIRM_YES:
        _providers = [];
        _currentIndex = 0;
        saveProviders();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        break;
      case WatchUi.CONFIRM_NO:
        break;
    }
  }
}

// Name, key and type input view stack

var _enteredName = "";

class NameInputDelegate extends TextInput.TextInputDelegate {
  function initialize(view) { TextInputDelegate.initialize(view); }
  function onTextEntered(text) {
    _enteredName = text;
    var view = new TextInput.TextInputView("Enter key", Alphabet.BASE32);
    WatchUi.pushView(view, new KeyInputDelegate(view), WatchUi.SLIDE_LEFT);
  }
}

var _enteredKey = "";

class KeyInputDelegate extends TextInput.TextInputDelegate {
  function initialize(view) { TextInputDelegate.initialize(view); }
  function onTextEntered(text) {
    _enteredKey = text;
    var menu = new WatchUi.Menu();
    menu.setTitle("Select type");
    menu.addItem("Time based", : time);
    menu.addItem("Counter based", : counter);
    menu.addItem("Steam guard", : steam);
    WatchUi.pushView(menu, new TypeMenuDelegate(), WatchUi.SLIDE_LEFT);
  }
}

class TypeMenuDelegate extends WatchUi.MenuInputDelegate {
  function initialize() { MenuInputDelegate.initialize(); }

  function onMenuItem(item) {
    var provider;
    switch (item) {
    case:
    time:
      provider = new TimeBasedProvider(_enteredName, _enteredKey, 30);
      break;
    case:
    counter:
      provider = new CounterBasedProvider(_enteredName, _enteredKey, 0);
      break;
    case:
    steam:
      provider = new SteamGuardProvider(_enteredName, _enteredKey, 30);
      break;
    }
    if (provider != null) {
      _providers.add(provider);
      _currentIndex = _providers.size() - 1;
      clearError();
      saveProviders();
    }
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
    WatchUi.popView(WatchUi.SLIDE_RIGHT);
  }
}
