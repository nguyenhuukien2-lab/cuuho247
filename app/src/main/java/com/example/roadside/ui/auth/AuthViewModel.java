package com.example.roadside.ui.auth;

import android.app.Application;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.example.roadside.data.models.User;
import com.example.roadside.data.repository.AuthRepository;

public class AuthViewModel extends AndroidViewModel {

    private final AuthRepository authRepository;
    private final MutableLiveData<Boolean> loginResult = new MutableLiveData<>();
    private final MutableLiveData<Boolean> registerResult = new MutableLiveData<>();

    public AuthViewModel(@NonNull Application application) {
        super(application);
        authRepository = new AuthRepository(application);
    }

    public LiveData<Boolean> getLoginResult() {
        return loginResult;
    }

    public LiveData<Boolean> getRegisterResult() {
        return registerResult;
    }

    public void login(String email, String password) {
        boolean success = authRepository.login(email, password);
        loginResult.setValue(success);
    }

    public void register(String name, String email, String phone, String password) {
        User user = new User(0, name, email, phone, password, "");
        boolean success = authRepository.register(user);
        registerResult.setValue(success);
    }

    public boolean isLoggedIn() {
        return authRepository.isLoggedIn();
    }

    public void logout() {
        authRepository.logout();
    }
}
