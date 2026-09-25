package com.example.roadside.ui.home;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.ImageButton;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.example.roadside.R;
import com.example.roadside.ui.history.HistoryActivity;
import com.example.roadside.ui.request.RequestFormActivity;

public class HomeActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_home);

        ImageButton btnRescueNow = findViewById(R.id.btnRescueNow);
        TextView btnHotline = findViewById(R.id.btnHotline);
        View navHistory = findViewById(R.id.navHistory);
        View navAccount = findViewById(R.id.navAccount);

        if (btnRescueNow != null) {
            btnRescueNow.setOnClickListener(v -> startActivity(new Intent(HomeActivity.this, RequestFormActivity.class)));
        }

        if (btnHotline != null) {
            btnHotline.setOnClickListener(v -> Toast.makeText(this, "Đang gọi tổng đài cứu hộ: 1900 6868", Toast.LENGTH_SHORT).show());
        }

        if (navHistory != null) {
            navHistory.setOnClickListener(v -> startActivity(new Intent(HomeActivity.this, HistoryActivity.class)));
        }

        if (navAccount != null) {
            navAccount.setOnClickListener(v -> Toast.makeText(this, "Thông tin tài khoản", Toast.LENGTH_SHORT).show());
        }
    }
}
