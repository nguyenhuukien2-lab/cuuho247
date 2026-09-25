package com.example.roadside.utils;

import android.content.Context;
import android.content.SharedPreferences;

public class SharedPrefsHelper {

    private final SharedPreferences prefs;

    public SharedPrefsHelper(Context context) {
        prefs = context.getSharedPreferences(Constants.PREF_NAME, Context.MODE_PRIVATE);
    }

    public void saveUserSession(int userId, String email, String name) {
        prefs.edit()
            .putInt(Constants.KEY_USER_ID, userId)
            .putString(Constants.KEY_USER_EMAIL, email)
            .putString(Constants.KEY_USER_NAME, name)
            .putBoolean(Constants.KEY_IS_LOGGED_IN, true)
            .apply();
    }

    public boolean isLoggedIn() {
        return prefs.getBoolean(Constants.KEY_IS_LOGGED_IN, false);
    }

    public int getUserId() {
        return prefs.getInt(Constants.KEY_USER_ID, -1);
    }

    public String getUserName() {
        return prefs.getString(Constants.KEY_USER_NAME, "Khách hàng");
    }

    public String getUserEmail() {
        return prefs.getString(Constants.KEY_USER_EMAIL, "");
    }

    public void clearSession() {
        prefs.edit().clear().apply();
    }
}
