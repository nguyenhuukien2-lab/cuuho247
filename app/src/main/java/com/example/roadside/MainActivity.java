package com.example.roadside;

import android.content.Intent;
import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;

import com.example.roadside.ui.auth.LoginActivity;
import com.example.roadside.ui.home.HomeActivity;
import com.example.roadside.utils.SharedPrefsHelper;

public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        SharedPrefsHelper prefsHelper = new SharedPrefsHelper(this);
        if (prefsHelper.isLoggedIn()) {
            startActivity(new Intent(this, HomeActivity.class));
        } else {
            startActivity(new Intent(this, LoginActivity.class));
        }
        finish();
    }
}
