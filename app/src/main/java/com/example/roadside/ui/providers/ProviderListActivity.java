package com.example.roadside.ui.providers;

import android.content.Intent;
import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.example.roadside.R;
import com.example.roadside.ui.tracking.TrackingActivity;

public class ProviderListActivity extends AppCompatActivity {

    private RecyclerView rvProviders;
    private ProviderAdapter adapter;
    private ProvidersViewModel viewModel;
    private int requestId = -1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_provider_list);

        requestId = getIntent().getIntExtra("request_id", -1);

        rvProviders = findViewById(R.id.rvProviders);
        rvProviders.setLayoutManager(new LinearLayoutManager(this));

        adapter = new ProviderAdapter(provider -> {
            Intent intent = new Intent(ProviderListActivity.this, TrackingActivity.class);
            intent.putExtra("request_id", requestId);
            intent.putExtra("provider_id", provider.getId());
            intent.putExtra("provider_name", provider.getName());
            intent.putExtra("provider_phone", provider.getPhone());
            startActivity(intent);
            finish();
        });
        rvProviders.setAdapter(adapter);

        viewModel = new ViewModelProvider(this).get(ProvidersViewModel.class);
        viewModel.getProviderList().observe(this, adapter::setProviders);
    }
}
