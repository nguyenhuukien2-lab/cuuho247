package com.example.roadside.ui.tracking;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;

import com.example.roadside.R;

public class TrackingActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_tracking);

        int requestId = getIntent().getIntExtra("request_id", 1);
        String pName = getIntent().getStringExtra("provider_name");
        String pPhone = getIntent().getStringExtra("provider_phone");
        String technicianPhone = pPhone != null ? pPhone : "19006868";

        TextView tvTechnicianName = findViewById(R.id.tvTechnicianName);
        TextView tvTrackingStatus = findViewById(R.id.tvTrackingStatus);
        Button btnCallTechnician = findViewById(R.id.btnCallTechnician);
        Button btnMessageTechnician = findViewById(R.id.btnMessageTechnician);
        Button btnCancelRequest = findViewById(R.id.btnCancelRequest);

        if (pName != null && tvTechnicianName != null) {
            tvTechnicianName.setText(pName);
        }

        TrackingViewModel viewModel = new ViewModelProvider(this).get(TrackingViewModel.class);
        viewModel.loadRequest(requestId);

        viewModel.getCurrentRequest().observe(this, request -> {
            if (request != null && tvTrackingStatus != null) {
                tvTrackingStatus.setText("Trạng thái: " + request.getStatus());
            }
        });

        if (btnCallTechnician != null) {
            btnCallTechnician.setOnClickListener(v -> {
                Intent callIntent = new Intent(Intent.ACTION_DIAL);
                callIntent.setData(Uri.parse("tel:" + technicianPhone));
                startActivity(callIntent);
            });
        }

        if (btnMessageTechnician != null) {
            btnMessageTechnician.setOnClickListener(v -> Toast.makeText(this, "Mở khung chat với kỹ thuật viên", Toast.LENGTH_SHORT).show());
        }

        if (btnCancelRequest != null) {
            btnCancelRequest.setOnClickListener(v -> {
                Toast.makeText(this, "Đã hủy yêu cầu cứu hộ", Toast.LENGTH_SHORT).show();
                finish();
            });
        }
    }
}
