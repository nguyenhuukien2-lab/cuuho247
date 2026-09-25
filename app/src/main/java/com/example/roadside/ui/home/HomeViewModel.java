package com.example.roadside.ui.home;

import android.app.Application;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.example.roadside.utils.SharedPrefsHelper;

public class HomeViewModel extends AndroidViewModel {

    private final SharedPrefsHelper prefsHelper;
    private final MutableLiveData<String> userName = new MutableLiveData<>();

    public HomeViewModel(@NonNull Application application) {
        super(application);
        prefsHelper = new SharedPrefsHelper(application);
        userName.setValue(prefsHelper.getUserName());
    }

    public LiveData<String> getUserName() {
        return userName;
    }

    public void logout() {
        prefsHelper.clearSession();
    }
}
