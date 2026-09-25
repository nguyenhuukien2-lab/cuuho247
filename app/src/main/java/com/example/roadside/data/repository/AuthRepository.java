package com.example.roadside.data.repository;

import android.content.Context;

import com.example.roadside.data.db.AppDatabase;
import com.example.roadside.data.db.UserDao;
import com.example.roadside.data.models.User;
import com.example.roadside.utils.SharedPrefsHelper;

public class AuthRepository {

    private final UserDao userDao;
    private final SharedPrefsHelper prefsHelper;

    public AuthRepository(Context context) {
        AppDatabase db = AppDatabase.getInstance(context);
        userDao = db.userDao();
        prefsHelper = new SharedPrefsHelper(context);
    }

    public boolean login(String email, String password) {
        User user = userDao.login(email, password);
        if (user != null) {
            prefsHelper.saveUserSession(user.getId(), user.getEmail(), user.getName());
            return true;
        }
        return false;
    }

    public boolean register(User user) {
        User existing = userDao.getUserByEmail(user.getEmail());
        if (existing != null) {
            return false;
        }
        long id = userDao.insert(user);
        if (id > 0) {
            user.setId((int) id);
            prefsHelper.saveUserSession(user.getId(), user.getEmail(), user.getName());
            return true;
        }
        return false;
    }

    public boolean isLoggedIn() {
        return prefsHelper.isLoggedIn();
    }

    public void logout() {
        prefsHelper.clearSession();
    }
}
