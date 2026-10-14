-- READ-ONLY production verification of Admin migration effects.
-- Generated from exact canonical SQL, validated against a clean Supabase LOCAL catalog.
-- Source SHA256 (UTF-8 LF):
-- backend/supabase/migrations/202610040001_admin_backend_foundation.sql f2d93fe0926bf1055eca345447d345f35d45e82aee380bce7519ba71298d48b1
-- backend/supabase/migrations/202610050001_display_codes.sql 73b1a87536b298b2813fc5889c23b759f38385a302740933f0ece54989f407fa
-- 040001 creates 8 admin_profiles columns; 050001 adds admin_code (9 total).
-- 050001 replaces 5 foundation views; compare their final definitions.
-- No application RPC is executed. No CREATE/TEMP/DML/nextval/setval/repair occurs.
-- Exact body/view text is deliberately fail-closed; formatting/version differences
-- must be reviewed, never silently waived. Expected/actual values identify drift.
-- Trigger function names are schema-qualified using pg_trigger.tgfoid, so a
-- different search_path cannot cause a false match or a cosmetic mismatch.
-- service_role grants were NOT revoked by these historical migrations; inspect
-- their effective EXECUTE separately below instead of inventing new semantics.
-- Run as SQL Editor / trusted owner with BYPASSRLS; all statements are read-only.
begin transaction isolation level repeatable read read only;
set local search_path=pg_catalog,public,private;
set local statement_timeout='60s';
set local lock_timeout='5s';

with expected as (
  select x->>'version' as version, x->>'object' as object, x->'actual' as expected
  from jsonb_array_elements($manifest$[
  {
    "actual": {
      "column_api_acl": [],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_audit_logs",
    "version": "202610040001"
  },
  {
    "actual": {
      "column_api_acl": [
        {
          "role": "authenticated",
          "column": "title",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "body",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "target_type",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "priority",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "target_user_id",
          "grantable": false,
          "privilege": "INSERT"
        }
      ],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_notifications",
    "version": "202610040001"
  },
  {
    "actual": {
      "column_api_acl": [
        {
          "role": "authenticated",
          "column": "id",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "full_name",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "full_name",
          "grantable": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "column": "role",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "role",
          "grantable": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "column": "status",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "status",
          "grantable": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "column": "phone",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "phone",
          "grantable": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "column": "avatar_url",
          "grantable": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "column": "avatar_url",
          "grantable": false,
          "privilege": "UPDATE"
        }
      ],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_profiles",
    "version": "202610040001"
  },
  {
    "actual": {
      "column_api_acl": [],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_rescuer_documents_view",
    "version": "202610040001"
  },
  {
    "actual": {
      "column_api_acl": [
        {
          "role": "authenticated",
          "column": "description",
          "grantable": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "column": "icon",
          "grantable": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "column": "base_price",
          "grantable": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "column": "price_unit",
          "grantable": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "column": "is_featured",
          "grantable": false,
          "privilege": "UPDATE"
        }
      ],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_service_catalog",
    "version": "202610040001"
  },
  {
    "actual": {
      "column_api_acl": [],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_services_view",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "id",
        "type": "uuid",
        "default": "gen_random_uuid()",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "admin_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "action",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "target_table",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "target_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "metadata",
        "type": "jsonb",
        "default": "'{}'::jsonb",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "ip_address",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "user_agent",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": "now()",
        "identity": "",
        "not_null": true,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_audit_logs",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "id",
        "type": "uuid",
        "default": "gen_random_uuid()",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "title",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "body",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "target_type",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "priority",
        "type": "text",
        "default": "'normal'::text",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "target_user_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_by",
        "type": "uuid",
        "default": "auth.uid()",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": "now()",
        "identity": "",
        "not_null": true,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_notifications",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "full_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "role",
        "type": "text",
        "default": "'operator'::text",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "status",
        "type": "text",
        "default": "'active'::text",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "phone",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "avatar_url",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": "now()",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "updated_at",
        "type": "timestamp with time zone",
        "default": "now()",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "admin_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": true,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_profiles",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "document_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "rescuer_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "document_type",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "vehicle_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "storage_path",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "content_type",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "byte_size",
        "type": "integer",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "uploaded_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "verification_status",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "expires_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_rescuer_documents_view",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "id",
        "type": "uuid",
        "default": "gen_random_uuid()",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "service_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "admin_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "description",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "icon",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "base_price",
        "type": "numeric(14,2)",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "price_unit",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "is_featured",
        "type": "boolean",
        "default": "false",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": "now()",
        "identity": "",
        "not_null": true,
        "generated": ""
      },
      {
        "name": "updated_at",
        "type": "timestamp with time zone",
        "default": "now()",
        "identity": "",
        "not_null": true,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_service_catalog",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "service_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "app_service_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "description",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "icon",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "base_price",
        "type": "numeric(14,2)",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "price_unit",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "is_active",
        "type": "boolean",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "is_featured",
        "type": "boolean",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "sort_order",
        "type": "integer",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "updated_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_services_view",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_audit_logs_action_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK (((length(btrim(action)) >= 1) AND (length(btrim(action)) <= 100)))"
      },
      {
        "name": "admin_audit_logs_admin_id_fkey",
        "type": "f",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "FOREIGN KEY (admin_id) REFERENCES auth.users(id) ON DELETE SET NULL"
      },
      {
        "name": "admin_audit_logs_metadata_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK ((jsonb_typeof(metadata) = 'object'::text))"
      },
      {
        "name": "admin_audit_logs_pkey",
        "type": "p",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "PRIMARY KEY (id)"
      }
    ],
    "object": "constraints:public.admin_audit_logs",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_notifications_body_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK (((length(btrim(body)) >= 1) AND (length(btrim(body)) <= 5000)))"
      },
      {
        "name": "admin_notifications_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK (((target_type = ANY (ARRAY['single_customer'::text, 'single_rescuer'::text])) = (target_user_id IS NOT NULL)))"
      },
      {
        "name": "admin_notifications_created_by_fkey",
        "type": "f",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE RESTRICT"
      },
      {
        "name": "admin_notifications_pkey",
        "type": "p",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "PRIMARY KEY (id)"
      },
      {
        "name": "admin_notifications_priority_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'emergency'::text])))"
      },
      {
        "name": "admin_notifications_target_type_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK ((target_type = ANY (ARRAY['all'::text, 'customers'::text, 'rescuers'::text, 'single_customer'::text, 'single_rescuer'::text])))"
      },
      {
        "name": "admin_notifications_target_user_id_fkey",
        "type": "f",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "FOREIGN KEY (target_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT"
      },
      {
        "name": "admin_notifications_title_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK (((length(btrim(title)) >= 1) AND (length(btrim(title)) <= 200)))"
      }
    ],
    "object": "constraints:public.admin_notifications",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_profiles_admin_code_format",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK (((admin_code ~ '^AD-[0-9]{6,}$'::text) AND ((SUBSTRING(admin_code FROM 4))::numeric > (0)::numeric)))"
      },
      {
        "name": "admin_profiles_full_name_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK (((length(btrim(full_name)) >= 1) AND (length(btrim(full_name)) <= 150)))"
      },
      {
        "name": "admin_profiles_id_fkey",
        "type": "f",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE"
      },
      {
        "name": "admin_profiles_pkey",
        "type": "p",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "PRIMARY KEY (id)"
      },
      {
        "name": "admin_profiles_role_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK ((role = ANY (ARRAY['super_admin'::text, 'operator'::text, 'support'::text, 'partner_reviewer'::text, 'finance'::text])))"
      },
      {
        "name": "admin_profiles_status_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK ((status = ANY (ARRAY['active'::text, 'blocked'::text])))"
      }
    ],
    "object": "constraints:public.admin_profiles",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_service_catalog_admin_code_key",
        "type": "u",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "UNIQUE (admin_code)"
      },
      {
        "name": "admin_service_catalog_base_price_check",
        "type": "c",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "CHECK (((base_price IS NULL) OR (base_price >= (0)::numeric)))"
      },
      {
        "name": "admin_service_catalog_pkey",
        "type": "p",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "PRIMARY KEY (id)"
      },
      {
        "name": "admin_service_catalog_service_code_fkey",
        "type": "f",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "FOREIGN KEY (service_code) REFERENCES rescue_services(code) ON DELETE RESTRICT"
      },
      {
        "name": "admin_service_catalog_service_code_key",
        "type": "u",
        "deferred": false,
        "validated": true,
        "deferrable": false,
        "definition": "UNIQUE (service_code)"
      }
    ],
    "object": "constraints:public.admin_service_catalog",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "trigger",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "",
        "signature": "private.admin_catalog_audit()",
        "volatility": "v",
        "body_sha256": "609191c0ecf67d470e7100caa5a67c225f24bec85707b623b82ca180d5f028cb",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.admin_catalog_audit",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "trigger",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "",
        "signature": "private.admin_catalog_guard()",
        "volatility": "v",
        "body_sha256": "bc8e0519b890541c491d6b31f30101d7f162a36b78a7c8a32a512cadbec221a8",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.admin_catalog_guard",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "p_id uuid, p_target text, p_reason text",
        "signature": "private.admin_change_rescuer(uuid, text, text)",
        "volatility": "v",
        "body_sha256": "3a87944abe9fb7d54c37913ace2a86a56ad0262c1bfd10a4c2359640d27df336",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.admin_change_rescuer",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "trigger",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "",
        "signature": "private.admin_notification_audit()",
        "volatility": "v",
        "body_sha256": "bbb99595349216954532aa8e8b0d49b2af3f55a5971b7e552026a8c55f046c41",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.admin_notification_audit",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "trigger",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "",
        "signature": "private.admin_notification_guard()",
        "volatility": "v",
        "body_sha256": "46053e3cd750427a6e7cdc03fa210b5659e96d06a37e62a9d8e337a896a68920",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.admin_notification_guard",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "trigger",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "",
        "signature": "private.admin_profile_audit()",
        "volatility": "v",
        "body_sha256": "f96b9225227ce1375233aadffe6370d5932899ae7c55c5f03bcce1c8bd0e0c12",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.admin_profile_audit",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "trigger",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "",
        "signature": "private.admin_profile_guard()",
        "volatility": "v",
        "body_sha256": "966e8d900120a4acd42f369f7d33a50f932e4d70e5c58337da6e854add4f0827",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.admin_profile_guard",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "void",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "p_roles text[]",
        "signature": "private.admin_require_role(text[])",
        "volatility": "v",
        "body_sha256": "cfb8055323043f0fb0e5eec200b3a5e27049d148242d019bdfa23e40077aca08",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.admin_require_role",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "rescuer_id uuid",
        "signature": "public.admin_approve_rescuer(uuid)",
        "volatility": "v",
        "body_sha256": "fd27603e99464912da5760381d66b273e34deb1bb3071d34277dc29f79c1ed6b",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": true,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.admin_approve_rescuer",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "rescuer_id uuid, reason text",
        "signature": "public.admin_block_rescuer(uuid, text)",
        "volatility": "v",
        "body_sha256": "bab0bedc3199e41cc53b94f4cd8f67d2f6af0d3df2018b3ff602755325b35858",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": true,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.admin_block_rescuer",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "request_id uuid, reason text",
        "signature": "public.admin_cancel_request(uuid, text)",
        "volatility": "v",
        "body_sha256": "0ce304597f5d09eca8b9312bd78ac7f08799da9fba1d9b04eef04f8be9ba2637",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": true,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.admin_cancel_request",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "",
        "signature": "public.admin_get_dashboard_stats()",
        "volatility": "v",
        "body_sha256": "c977a56d0f7113286273dde7c04e004c7b8dd9c9a73ad48526a556f25bfc6094",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": true,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.admin_get_dashboard_stats",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "void",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "p_action text, p_target_table text DEFAULT NULL::text, p_target_id uuid DEFAULT NULL::uuid, p_metadata jsonb DEFAULT '{}'::jsonb",
        "signature": "public.admin_log_action(text, text, uuid, jsonb)",
        "volatility": "v",
        "body_sha256": "1b2d49af759bf32d73d29faf31bf2e689e9549f992f103097d999e4d87fee726",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.admin_log_action",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "rescuer_id uuid, reason text",
        "signature": "public.admin_reject_rescuer(uuid, text)",
        "volatility": "v",
        "body_sha256": "433aecd7c8e690d8df93016a4b6c94d1c3b8cd0d81bcbb10f1d77f42aa4fa75b",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": true,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.admin_reject_rescuer",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "service_id uuid, is_active boolean",
        "signature": "public.admin_toggle_service(uuid, boolean)",
        "volatility": "v",
        "body_sha256": "ff9b38ec8e8562d0923e5494fcffbcdc115444fad36b2a90bcd5105f36de56ed",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": true,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.admin_toggle_service",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "boolean",
        "strict": false,
        "definer": true,
        "language": "sql",
        "arguments": "required_roles text[]",
        "signature": "public.has_admin_role(text[])",
        "volatility": "s",
        "body_sha256": "a8b621150a224ccf9d536324f915be417daf6ca9de8e216ca8d3477143f09aa5",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": true,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.has_admin_role",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=public"
        ],
        "result": "boolean",
        "strict": false,
        "definer": true,
        "language": "sql",
        "arguments": "",
        "signature": "public.is_admin()",
        "volatility": "s",
        "body_sha256": "6fae7fbb2feffff603b766bbbc8ad9eea19a79c9dfe1849eb45e14c8ac32289d",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": true,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.is_admin",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_audit_actor_time_idx",
        "ready": true,
        "valid": true,
        "unique": false,
        "primary": false,
        "definition": "CREATE INDEX admin_audit_actor_time_idx ON public.admin_audit_logs USING btree (admin_id, created_at DESC)"
      },
      {
        "name": "admin_audit_logs_pkey",
        "ready": true,
        "valid": true,
        "unique": true,
        "primary": true,
        "definition": "CREATE UNIQUE INDEX admin_audit_logs_pkey ON public.admin_audit_logs USING btree (id)"
      },
      {
        "name": "admin_audit_target_idx",
        "ready": true,
        "valid": true,
        "unique": false,
        "primary": false,
        "definition": "CREATE INDEX admin_audit_target_idx ON public.admin_audit_logs USING btree (target_table, target_id)"
      },
      {
        "name": "admin_audit_time_idx",
        "ready": true,
        "valid": true,
        "unique": false,
        "primary": false,
        "definition": "CREATE INDEX admin_audit_time_idx ON public.admin_audit_logs USING btree (created_at DESC, id)"
      }
    ],
    "object": "indexes:public.admin_audit_logs",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_notification_time_idx",
        "ready": true,
        "valid": true,
        "unique": false,
        "primary": false,
        "definition": "CREATE INDEX admin_notification_time_idx ON public.admin_notifications USING btree (created_at DESC, id)"
      },
      {
        "name": "admin_notifications_pkey",
        "ready": true,
        "valid": true,
        "unique": true,
        "primary": true,
        "definition": "CREATE UNIQUE INDEX admin_notifications_pkey ON public.admin_notifications USING btree (id)"
      }
    ],
    "object": "indexes:public.admin_notifications",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_profiles_admin_code_uidx",
        "ready": true,
        "valid": true,
        "unique": true,
        "primary": false,
        "definition": "CREATE UNIQUE INDEX admin_profiles_admin_code_uidx ON public.admin_profiles USING btree (admin_code)"
      },
      {
        "name": "admin_profiles_pkey",
        "ready": true,
        "valid": true,
        "unique": true,
        "primary": true,
        "definition": "CREATE UNIQUE INDEX admin_profiles_pkey ON public.admin_profiles USING btree (id)"
      }
    ],
    "object": "indexes:public.admin_profiles",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_service_catalog_admin_code_key",
        "ready": true,
        "valid": true,
        "unique": true,
        "primary": false,
        "definition": "CREATE UNIQUE INDEX admin_service_catalog_admin_code_key ON public.admin_service_catalog USING btree (admin_code)"
      },
      {
        "name": "admin_service_catalog_pkey",
        "ready": true,
        "valid": true,
        "unique": true,
        "primary": true,
        "definition": "CREATE UNIQUE INDEX admin_service_catalog_pkey ON public.admin_service_catalog USING btree (id)"
      },
      {
        "name": "admin_service_catalog_service_code_key",
        "ready": true,
        "valid": true,
        "unique": true,
        "primary": false,
        "definition": "CREATE UNIQUE INDEX admin_service_catalog_service_code_key ON public.admin_service_catalog USING btree (service_code)"
      }
    ],
    "object": "indexes:public.admin_service_catalog",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_audit_read",
        "check": null,
        "roles": [
          "authenticated"
        ],
        "using": "( SELECT is_admin() AS is_admin)",
        "command": "r",
        "permissive": true
      }
    ],
    "object": "policies:public.admin_audit_logs",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_notifications_insert",
        "check": "(( SELECT has_admin_role(ARRAY['super_admin'::text, 'operator'::text, 'support'::text]) AS has_admin_role) AND (created_by = ( SELECT auth.uid() AS uid)))",
        "roles": [
          "authenticated"
        ],
        "using": null,
        "command": "a",
        "permissive": true
      },
      {
        "name": "admin_notifications_read",
        "check": null,
        "roles": [
          "authenticated"
        ],
        "using": "( SELECT is_admin() AS is_admin)",
        "command": "r",
        "permissive": true
      }
    ],
    "object": "policies:public.admin_notifications",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_profiles_insert",
        "check": "( SELECT has_admin_role(ARRAY['super_admin'::text]) AS has_admin_role)",
        "roles": [
          "authenticated"
        ],
        "using": null,
        "command": "a",
        "permissive": true
      },
      {
        "name": "admin_profiles_read",
        "check": null,
        "roles": [
          "authenticated"
        ],
        "using": "( SELECT is_admin() AS is_admin)",
        "command": "r",
        "permissive": true
      },
      {
        "name": "admin_profiles_update",
        "check": "( SELECT has_admin_role(ARRAY['super_admin'::text]) AS has_admin_role)",
        "roles": [
          "authenticated"
        ],
        "using": "( SELECT has_admin_role(ARRAY['super_admin'::text]) AS has_admin_role)",
        "command": "w",
        "permissive": true
      }
    ],
    "object": "policies:public.admin_profiles",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_catalog_read",
        "check": null,
        "roles": [
          "authenticated"
        ],
        "using": "( SELECT is_admin() AS is_admin)",
        "command": "r",
        "permissive": true
      },
      {
        "name": "admin_catalog_update",
        "check": "( SELECT has_admin_role(ARRAY['super_admin'::text, 'operator'::text]) AS has_admin_role)",
        "roles": [
          "authenticated"
        ],
        "using": "( SELECT has_admin_role(ARRAY['super_admin'::text, 'operator'::text]) AS has_admin_role)",
        "command": "w",
        "permissive": true
      }
    ],
    "object": "policies:public.admin_service_catalog",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_services_read",
        "check": null,
        "roles": [
          "authenticated"
        ],
        "using": "( SELECT is_admin() AS is_admin)",
        "command": "r",
        "permissive": true
      },
      {
        "name": "admin_services_update",
        "check": "( SELECT has_admin_role(ARRAY['super_admin'::text, 'operator'::text]) AS has_admin_role)",
        "roles": [
          "authenticated"
        ],
        "using": "( SELECT has_admin_role(ARRAY['super_admin'::text, 'operator'::text]) AS has_admin_role)",
        "command": "w",
        "permissive": true
      }
    ],
    "object": "policies:public.rescue_services:admin",
    "version": "202610040001"
  },
  {
    "actual": {
      "rls": true,
      "kind": "r",
      "options": [],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_audit_logs",
    "version": "202610040001"
  },
  {
    "actual": {
      "rls": true,
      "kind": "r",
      "options": [],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_notifications",
    "version": "202610040001"
  },
  {
    "actual": {
      "rls": true,
      "kind": "r",
      "options": [],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_profiles",
    "version": "202610040001"
  },
  {
    "actual": {
      "rls": false,
      "kind": "v",
      "options": [
        "security_barrier=true",
        "security_invoker=false"
      ],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_rescuer_documents_view",
    "version": "202610040001"
  },
  {
    "actual": {
      "rls": true,
      "kind": "r",
      "options": [],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_service_catalog",
    "version": "202610040001"
  },
  {
    "actual": {
      "rls": false,
      "kind": "v",
      "options": [
        "security_barrier=true",
        "security_invoker=false"
      ],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_services_view",
    "version": "202610040001"
  },
  {
    "actual": [],
    "object": "triggers:public.admin_audit_logs",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_notification_audit",
        "enabled": "O",
        "definition": "CREATE TRIGGER admin_notification_audit AFTER INSERT ON public.admin_notifications FOR EACH ROW EXECUTE FUNCTION private.admin_notification_audit()"
      },
      {
        "name": "admin_notification_guard",
        "enabled": "O",
        "definition": "CREATE TRIGGER admin_notification_guard BEFORE INSERT ON public.admin_notifications FOR EACH ROW EXECUTE FUNCTION private.admin_notification_guard()"
      }
    ],
    "object": "triggers:public.admin_notifications",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_profile_audit",
        "enabled": "O",
        "definition": "CREATE TRIGGER admin_profile_audit AFTER INSERT OR UPDATE ON public.admin_profiles FOR EACH ROW EXECUTE FUNCTION private.admin_profile_audit()"
      },
      {
        "name": "admin_profile_guard",
        "enabled": "O",
        "definition": "CREATE TRIGGER admin_profile_guard BEFORE INSERT OR UPDATE ON public.admin_profiles FOR EACH ROW EXECUTE FUNCTION private.admin_profile_guard()"
      },
      {
        "name": "admin_profiles_display_code",
        "enabled": "O",
        "definition": "CREATE TRIGGER admin_profiles_display_code BEFORE INSERT OR UPDATE OF admin_code ON public.admin_profiles FOR EACH ROW EXECUTE FUNCTION private.assign_display_code('admin_code', 'public.admin_code_seq', 'AD')"
      }
    ],
    "object": "triggers:public.admin_profiles",
    "version": "202610040001"
  },
  {
    "actual": [
      {
        "name": "admin_catalog_audit",
        "enabled": "O",
        "definition": "CREATE TRIGGER admin_catalog_audit AFTER UPDATE ON public.admin_service_catalog FOR EACH ROW EXECUTE FUNCTION private.admin_catalog_audit()"
      },
      {
        "name": "admin_catalog_guard",
        "enabled": "O",
        "definition": "CREATE TRIGGER admin_catalog_guard BEFORE UPDATE ON public.admin_service_catalog FOR EACH ROW EXECUTE FUNCTION private.admin_catalog_guard()"
      }
    ],
    "object": "triggers:public.admin_service_catalog",
    "version": "202610040001"
  },
  {
    "actual": " SELECT id AS document_id,\n    rescuer_id,\n    document_type,\n    vehicle_id,\n    storage_path,\n    content_type,\n    byte_size,\n    uploaded_at,\n    verification_status,\n    expires_at,\n    created_at\n   FROM rescuer_documents d\n  WHERE ( SELECT has_admin_role(ARRAY['super_admin'::text, 'partner_reviewer'::text]) AS has_admin_role);",
    "object": "view:public.admin_rescuer_documents_view",
    "version": "202610040001"
  },
  {
    "actual": " SELECT m.id AS service_id,\n    m.admin_code AS code,\n    s.code AS app_service_code,\n    s.name,\n    m.description,\n    m.icon,\n    m.base_price,\n    m.price_unit,\n    s.is_active,\n    m.is_featured,\n    s.sort_order,\n    m.created_at,\n    m.updated_at\n   FROM (admin_service_catalog m\n     JOIN rescue_services s ON ((s.code = m.service_code)))\n  WHERE ( SELECT is_admin() AS is_admin);",
    "object": "view:public.admin_services_view",
    "version": "202610040001"
  },
  {
    "actual": {
      "column_api_acl": [],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_customers_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "column_api_acl": [],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_quotes_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "column_api_acl": [],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_rescue_requests_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "column_api_acl": [],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_rescuers_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "column_api_acl": [],
      "explicit_api_acl": [
        {
          "role": "authenticated",
          "grantable": false,
          "privilege": "SELECT"
        }
      ],
      "effective_api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "DELETE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "INSERT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "REFERENCES"
        },
        {
          "role": "authenticated",
          "allowed": true,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRIGGER"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "TRUNCATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        }
      ]
    },
    "object": "acl:public.admin_reviews_view",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "name": "customer_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "full_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "email",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "phone",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "avatar_url",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "vehicle_count",
        "type": "bigint",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "address_count",
        "type": "bigint",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "request_count",
        "type": "bigint",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "completed_count",
        "type": "bigint",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "total_spent",
        "type": "numeric",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "status",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "customer_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_customers_view",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "name": "quote_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "request_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "request_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "customer_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "rescuer_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "service_type",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "amount",
        "type": "numeric",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "note",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "status",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "currency",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "revision",
        "type": "integer",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "is_current",
        "type": "boolean",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "is_completion_quote",
        "type": "boolean",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "quote_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_quotes_view",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "name": "request_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "request_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "customer_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "customer_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "customer_phone",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "customer_email",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "service_type",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "problem_description",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "vehicle_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "vehicle_plate",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "status",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "pickup_address",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "pickup_lat",
        "type": "double precision",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "pickup_lng",
        "type": "double precision",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "destination_address",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "accepted_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "completed_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "rescuer_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "rescuer_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "rescuer_phone",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "quote_amount",
        "type": "numeric",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "quote_status",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_rescue_requests_view",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "name": "rescuer_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "full_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "phone",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "email",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "approval_status",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "online_status",
        "type": "boolean",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "last_seen_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "is_available",
        "type": "boolean",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "vehicle_count",
        "type": "bigint",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "service_count",
        "type": "bigint",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "completed_jobs",
        "type": "bigint",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "average_rating",
        "type": "numeric",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "version",
        "type": "bigint",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "rescuer_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_rescuers_view",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "name": "review_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "request_id",
        "type": "uuid",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "request_code",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "customer_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "rescuer_name",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "rating",
        "type": "integer",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "comment",
        "type": "text",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      },
      {
        "name": "created_at",
        "type": "timestamp with time zone",
        "default": null,
        "identity": "",
        "not_null": false,
        "generated": ""
      }
    ],
    "object": "columns:public.admin_reviews_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "type": "text",
      "default": null,
      "identity": "",
      "not_null": true,
      "generated": ""
    },
    "object": "display_column:public.admin_profiles.admin_code",
    "version": "202610050001"
  },
  {
    "actual": {
      "type": "text",
      "default": null,
      "identity": "",
      "not_null": true,
      "generated": ""
    },
    "object": "display_column:public.customer_profiles.customer_code",
    "version": "202610050001"
  },
  {
    "actual": {
      "type": "text",
      "default": null,
      "identity": "",
      "not_null": true,
      "generated": ""
    },
    "object": "display_column:public.rescue_quotes.quote_code",
    "version": "202610050001"
  },
  {
    "actual": {
      "type": "text",
      "default": null,
      "identity": "",
      "not_null": true,
      "generated": ""
    },
    "object": "display_column:public.rescue_requests.request_code",
    "version": "202610050001"
  },
  {
    "actual": {
      "type": "text",
      "default": null,
      "identity": "",
      "not_null": true,
      "generated": ""
    },
    "object": "display_column:public.rescuer_profiles.rescuer_code",
    "version": "202610050001"
  },
  {
    "actual": {
      "validated": true,
      "definition": "CHECK (((admin_code ~ '^AD-[0-9]{6,}$'::text) AND ((SUBSTRING(admin_code FROM 4))::numeric > (0)::numeric)))"
    },
    "object": "display_constraint:public.admin_profiles",
    "version": "202610050001"
  },
  {
    "actual": {
      "validated": true,
      "definition": "CHECK (((customer_code ~ '^KH-[0-9]{6,}$'::text) AND ((SUBSTRING(customer_code FROM 4))::numeric > (0)::numeric)))"
    },
    "object": "display_constraint:public.customer_profiles",
    "version": "202610050001"
  },
  {
    "actual": {
      "validated": true,
      "definition": "CHECK (((quote_code ~ '^BG-[0-9]{6,}$'::text) AND ((SUBSTRING(quote_code FROM 4))::numeric > (0)::numeric)))"
    },
    "object": "display_constraint:public.rescue_quotes",
    "version": "202610050001"
  },
  {
    "actual": {
      "validated": true,
      "definition": "CHECK (((request_code ~ '^CH-[0-9]{6,}$'::text) AND ((SUBSTRING(request_code FROM 4))::numeric > (0)::numeric)))"
    },
    "object": "display_constraint:public.rescue_requests",
    "version": "202610050001"
  },
  {
    "actual": {
      "validated": true,
      "definition": "CHECK (((rescuer_code ~ '^DT-[0-9]{6,}$'::text) AND ((SUBSTRING(rescuer_code FROM 4))::numeric > (0)::numeric)))"
    },
    "object": "display_constraint:public.rescuer_profiles",
    "version": "202610050001"
  },
  {
    "actual": {
      "ready": true,
      "valid": true,
      "unique": true,
      "definition": "CREATE UNIQUE INDEX admin_profiles_admin_code_uidx ON public.admin_profiles USING btree (admin_code)"
    },
    "object": "display_index:public.admin_profiles",
    "version": "202610050001"
  },
  {
    "actual": {
      "ready": true,
      "valid": true,
      "unique": true,
      "definition": "CREATE UNIQUE INDEX customer_profiles_customer_code_uidx ON public.customer_profiles USING btree (customer_code)"
    },
    "object": "display_index:public.customer_profiles",
    "version": "202610050001"
  },
  {
    "actual": {
      "ready": true,
      "valid": true,
      "unique": true,
      "definition": "CREATE UNIQUE INDEX rescue_quotes_quote_code_uidx ON public.rescue_quotes USING btree (quote_code)"
    },
    "object": "display_index:public.rescue_quotes",
    "version": "202610050001"
  },
  {
    "actual": {
      "ready": true,
      "valid": true,
      "unique": true,
      "definition": "CREATE UNIQUE INDEX rescue_requests_request_code_uidx ON public.rescue_requests USING btree (request_code)"
    },
    "object": "display_index:public.rescue_requests",
    "version": "202610050001"
  },
  {
    "actual": {
      "ready": true,
      "valid": true,
      "unique": true,
      "definition": "CREATE UNIQUE INDEX rescuer_profiles_rescuer_code_uidx ON public.rescuer_profiles USING btree (rescuer_code)"
    },
    "object": "display_index:public.rescuer_profiles",
    "version": "202610050001"
  },
  {
    "actual": {
      "enabled": "O",
      "definition": "CREATE TRIGGER admin_profiles_display_code BEFORE INSERT OR UPDATE OF admin_code ON public.admin_profiles FOR EACH ROW EXECUTE FUNCTION private.assign_display_code('admin_code', 'public.admin_code_seq', 'AD')"
    },
    "object": "display_trigger:public.admin_profiles",
    "version": "202610050001"
  },
  {
    "actual": {
      "enabled": "O",
      "definition": "CREATE TRIGGER customer_profiles_display_code BEFORE INSERT OR UPDATE OF customer_code ON public.customer_profiles FOR EACH ROW EXECUTE FUNCTION private.assign_display_code('customer_code', 'public.customer_code_seq', 'KH')"
    },
    "object": "display_trigger:public.customer_profiles",
    "version": "202610050001"
  },
  {
    "actual": {
      "enabled": "O",
      "definition": "CREATE TRIGGER rescue_quotes_display_code BEFORE INSERT OR UPDATE OF quote_code ON public.rescue_quotes FOR EACH ROW EXECUTE FUNCTION private.assign_display_code('quote_code', 'public.quote_code_seq', 'BG')"
    },
    "object": "display_trigger:public.rescue_quotes",
    "version": "202610050001"
  },
  {
    "actual": {
      "enabled": "O",
      "definition": "CREATE TRIGGER rescue_requests_display_code BEFORE INSERT OR UPDATE OF request_code ON public.rescue_requests FOR EACH ROW EXECUTE FUNCTION private.assign_display_code('request_code', 'public.request_code_seq', 'CH')"
    },
    "object": "display_trigger:public.rescue_requests",
    "version": "202610050001"
  },
  {
    "actual": {
      "enabled": "O",
      "definition": "CREATE TRIGGER rescuer_profiles_display_code BEFORE INSERT OR UPDATE OF rescuer_code ON public.rescuer_profiles FOR EACH ROW EXECUTE FUNCTION private.assign_display_code('rescuer_code', 'public.rescuer_code_seq', 'DT')"
    },
    "object": "display_trigger:public.rescuer_profiles",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=\"\""
        ],
        "result": "trigger",
        "strict": false,
        "definer": true,
        "language": "plpgsql",
        "arguments": "",
        "signature": "private.assign_display_code()",
        "volatility": "v",
        "body_sha256": "58f1ecd57c0ab27efcc2220e5c20dfcd9cf46f4376642a01698bbe2517b24e4f",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.assign_display_code",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=\"\""
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "sql",
        "arguments": "p_id uuid",
        "signature": "private.rescuer_assignment_dto(uuid)",
        "volatility": "s",
        "body_sha256": "299e06990d7c166e1cf3d3eb8d0c1efb2d12ae904aefc214a1cc25fa30a0dfa5",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.rescuer_assignment_dto",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=\"\""
        ],
        "result": "jsonb",
        "strict": false,
        "definer": false,
        "language": "sql",
        "arguments": "p_id uuid, p_lat double precision, p_lon double precision, p_service text, p_kind text, p_distance integer",
        "signature": "private.rescuer_available_dto(uuid, double precision, double precision, text, text, integer)",
        "volatility": "s",
        "body_sha256": "610123d85e1c10ac116e84d6801c84dea61ee4ee58c46fb1c03cb110ac63aae1",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.rescuer_available_dto",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=\"\""
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "sql",
        "arguments": "",
        "signature": "private.rescuer_profile_dto()",
        "volatility": "s",
        "body_sha256": "5e116d03058c905324d77388662f6cf514e155ffe888e31a868b507f4ddcad60",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.rescuer_profile_dto",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=\"\""
        ],
        "result": "jsonb",
        "strict": false,
        "definer": true,
        "language": "sql",
        "arguments": "p_id uuid",
        "signature": "private.rescuer_quote_dto(uuid)",
        "volatility": "s",
        "body_sha256": "2f27a2f2bda1161d0779d7c5a72675d74c4e6bd0d7d12ebfdbcac4022aff62c7",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:private.rescuer_quote_dto",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=\"\""
        ],
        "result": "TABLE(request_id uuid, quote_code text)",
        "strict": false,
        "definer": true,
        "language": "sql",
        "arguments": "p_request_ids uuid[]",
        "signature": "public.customer_request_display_codes(uuid[])",
        "volatility": "s",
        "body_sha256": "c7821e3c67666a32727e658e15e83d511108040973f36b71708f0375831179b4",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": true,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.customer_request_display_codes",
    "version": "202610050001"
  },
  {
    "actual": [
      {
        "config": [
          "search_path=\"\""
        ],
        "result": "text",
        "strict": true,
        "definer": false,
        "language": "plpgsql",
        "arguments": "prefix text, value bigint",
        "signature": "public.format_display_code(text, bigint)",
        "volatility": "i",
        "body_sha256": "a5d8790a9b6413e7a09b5757c091b7817b24d732559ccea8df687cf3824d6ea5",
        "anon_execute": false,
        "trusted_owner": true,
        "public_execute": false,
        "authenticated_execute": false,
        "api_execute_grant_option": false
      }
    ],
    "object": "function:public.format_display_code",
    "version": "202610050001"
  },
  {
    "actual": {
      "rls": false,
      "kind": "v",
      "options": [
        "security_barrier=true",
        "security_invoker=false"
      ],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_customers_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "rls": false,
      "kind": "v",
      "options": [
        "security_barrier=true",
        "security_invoker=false"
      ],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_quotes_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "rls": false,
      "kind": "v",
      "options": [
        "security_barrier=true",
        "security_invoker=false"
      ],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_rescue_requests_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "rls": false,
      "kind": "v",
      "options": [
        "security_barrier=true",
        "security_invoker=false"
      ],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_rescuers_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "rls": false,
      "kind": "v",
      "options": [
        "security_barrier=true",
        "security_invoker=false"
      ],
      "force_rls": false,
      "trusted_owner": true
    },
    "object": "relation:public.admin_reviews_view",
    "version": "202610050001"
  },
  {
    "actual": {
      "max": "9223372036854775807",
      "min": "1",
      "type": "bigint",
      "cache": "1",
      "cycle": false,
      "start": "1",
      "api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "USAGE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "USAGE"
        }
      ],
      "increment": "1",
      "public_acl": false,
      "trusted_owner": true
    },
    "object": "sequence:public.admin_code_seq",
    "version": "202610050001"
  },
  {
    "actual": {
      "max": "9223372036854775807",
      "min": "1",
      "type": "bigint",
      "cache": "1",
      "cycle": false,
      "start": "1",
      "api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "USAGE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "USAGE"
        }
      ],
      "increment": "1",
      "public_acl": false,
      "trusted_owner": true
    },
    "object": "sequence:public.customer_code_seq",
    "version": "202610050001"
  },
  {
    "actual": {
      "max": "9223372036854775807",
      "min": "1",
      "type": "bigint",
      "cache": "1",
      "cycle": false,
      "start": "1",
      "api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "USAGE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "USAGE"
        }
      ],
      "increment": "1",
      "public_acl": false,
      "trusted_owner": true
    },
    "object": "sequence:public.quote_code_seq",
    "version": "202610050001"
  },
  {
    "actual": {
      "max": "9223372036854775807",
      "min": "1",
      "type": "bigint",
      "cache": "1",
      "cycle": false,
      "start": "1",
      "api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "USAGE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "USAGE"
        }
      ],
      "increment": "1",
      "public_acl": false,
      "trusted_owner": true
    },
    "object": "sequence:public.request_code_seq",
    "version": "202610050001"
  },
  {
    "actual": {
      "max": "9223372036854775807",
      "min": "1",
      "type": "bigint",
      "cache": "1",
      "cycle": false,
      "start": "1",
      "api_acl": [
        {
          "role": "anon",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "anon",
          "allowed": false,
          "privilege": "USAGE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "SELECT"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "UPDATE"
        },
        {
          "role": "authenticated",
          "allowed": false,
          "privilege": "USAGE"
        }
      ],
      "increment": "1",
      "public_acl": false,
      "trusted_owner": true
    },
    "object": "sequence:public.rescuer_code_seq",
    "version": "202610050001"
  },
  {
    "actual": " SELECT c.user_id AS customer_id,\n    c.full_name,\n    (u.email)::text AS email,\n    c.phone,\n    NULL::text AS avatar_url,\n    ( SELECT count(*) AS count\n           FROM customer_vehicles v\n          WHERE (v.customer_id = c.user_id)) AS vehicle_count,\n    ( SELECT count(*) AS count\n           FROM customer_saved_addresses s\n          WHERE (s.customer_id = c.user_id)) AS address_count,\n    ( SELECT count(*) AS count\n           FROM rescue_requests r\n          WHERE (r.customer_id = c.user_id)) AS request_count,\n    ( SELECT count(*) AS count\n           FROM rescue_requests r\n          WHERE ((r.customer_id = c.user_id) AND (r.status = 'completed'::text))) AS completed_count,\n    (0)::numeric AS total_spent,\n    c.created_at,\n    NULL::text AS status,\n    c.customer_code\n   FROM (customer_profiles c\n     LEFT JOIN auth.users u ON ((u.id = c.user_id)))\n  WHERE ( SELECT has_admin_role(ARRAY['super_admin'::text, 'operator'::text, 'support'::text]) AS has_admin_role);",
    "object": "view:public.admin_customers_view",
    "version": "202610050001"
  },
  {
    "actual": " SELECT q.id AS quote_id,\n    q.request_id,\n    r.request_code,\n    COALESCE(NULLIF(c.full_name, ''::text), r.contact_name) AS customer_name,\n    p.full_name AS rescuer_name,\n    r.service_code AS service_type,\n    (q.total_vnd)::numeric AS amount,\n    q.note,\n    q.status,\n    q.issued_at AS created_at,\n    q.currency,\n    q.revision,\n    (q.id = a.current_quote_id) AS is_current,\n    ((q.id = a.completion_quote_id) AND (a.state = 'completed'::text)) AS is_completion_quote,\n    q.quote_code\n   FROM ((((rescue_quotes q\n     JOIN rescue_requests r ON ((r.id = q.request_id)))\n     JOIN rescue_request_assignments a ON ((a.id = q.assignment_id)))\n     LEFT JOIN customer_profiles c ON ((c.user_id = r.customer_id)))\n     LEFT JOIN rescuer_profiles p ON ((p.user_id = q.rescuer_id)))\n  WHERE ( SELECT has_admin_role(ARRAY['super_admin'::text, 'finance'::text]) AS has_admin_role);",
    "object": "view:public.admin_quotes_view",
    "version": "202610050001"
  },
  {
    "actual": " SELECT r.id AS request_id,\n    r.request_code,\n    r.customer_id,\n    COALESCE(NULLIF(c.full_name, ''::text), r.contact_name) AS customer_name,\n    COALESCE(c.phone, r.contact_phone) AS customer_phone,\n    (u.email)::text AS customer_email,\n    r.service_code AS service_type,\n    r.description AS problem_description,\n    v.display_name AS vehicle_name,\n    v.license_plate AS vehicle_plate,\n    r.status,\n    r.location_text AS pickup_address,\n    r.latitude AS pickup_lat,\n    r.longitude AS pickup_lng,\n    NULL::text AS destination_address,\n    r.created_at,\n    COALESCE(a.accepted_at, e.accepted_at) AS accepted_at,\n    COALESCE(a.completed_at, e.completed_at) AS completed_at,\n    COALESCE(a.rescuer_id, r.provider_id) AS rescuer_id,\n    p.full_name AS rescuer_name,\n    p.contact_phone AS rescuer_phone,\n        CASE\n            WHEN has_admin_role(ARRAY['super_admin'::text, 'finance'::text]) THEN (q.total_vnd)::numeric\n            ELSE NULL::numeric\n        END AS quote_amount,\n    q.status AS quote_status\n   FROM (((((((rescue_requests r\n     LEFT JOIN customer_profiles c ON ((c.user_id = r.customer_id)))\n     LEFT JOIN auth.users u ON ((u.id = r.customer_id)))\n     LEFT JOIN customer_vehicles v ON (((v.id = r.vehicle_id) AND (v.customer_id = r.customer_id))))\n     LEFT JOIN rescue_request_assignments a ON ((a.request_id = r.id)))\n     LEFT JOIN rescuer_profiles p ON ((p.user_id = COALESCE(a.rescuer_id, r.provider_id))))\n     LEFT JOIN rescue_quotes q ON (((q.id = a.current_quote_id) AND (q.assignment_id = a.id))))\n     LEFT JOIN LATERAL ( SELECT min(s.occurred_at) FILTER (WHERE ((s.status = 'accepted'::text) AND (NOT s.is_initial_snapshot))) AS accepted_at,\n            min(s.occurred_at) FILTER (WHERE ((s.status = 'completed'::text) AND (NOT s.is_initial_snapshot))) AS completed_at\n           FROM request_status_events s\n          WHERE (s.request_id = r.id)) e ON (true))\n  WHERE ( SELECT has_admin_role(ARRAY['super_admin'::text, 'operator'::text, 'support'::text]) AS has_admin_role);",
    "object": "view:public.admin_rescue_requests_view",
    "version": "202610050001"
  },
  {
    "actual": " SELECT p.user_id AS rescuer_id,\n    p.full_name,\n    p.contact_phone AS phone,\n    (u.email)::text AS email,\n    p.verification_status AS approval_status,\n    COALESCE(o.is_online, false) AS online_status,\n    o.last_seen_at,\n    COALESCE((o.is_online AND (p.verification_status = 'approved'::text) AND (o.last_seen_at >= (now() - '00:02:00'::interval))), false) AS is_available,\n    ( SELECT count(*) AS count\n           FROM rescuer_vehicles v\n          WHERE (v.rescuer_id = p.user_id)) AS vehicle_count,\n    ( SELECT count(DISTINCT c.service_code) AS count\n           FROM rescuer_service_capabilities c\n          WHERE ((c.rescuer_id = p.user_id) AND c.is_enabled AND (c.verification_status = 'approved'::text))) AS service_count,\n    ( SELECT count(*) AS count\n           FROM rescue_request_assignments a\n          WHERE ((a.rescuer_id = p.user_id) AND (a.state = 'completed'::text))) AS completed_jobs,\n    COALESCE(( SELECT round(avg(v.rating), 2) AS round\n           FROM (customer_request_reviews v\n             JOIN rescue_requests r ON ((r.id = v.request_id)))\n          WHERE (r.provider_id = p.user_id)), (0)::numeric) AS average_rating,\n    p.created_at,\n    p.version,\n    p.rescuer_code\n   FROM ((rescuer_profiles p\n     LEFT JOIN auth.users u ON ((u.id = p.user_id)))\n     LEFT JOIN rescuer_online_status o ON ((o.rescuer_id = p.user_id)))\n  WHERE ( SELECT has_admin_role(ARRAY['super_admin'::text, 'operator'::text, 'partner_reviewer'::text]) AS has_admin_role);",
    "object": "view:public.admin_rescuers_view",
    "version": "202610050001"
  },
  {
    "actual": " SELECT v.id AS review_id,\n    v.request_id,\n    r.request_code,\n    COALESCE(NULLIF(c.full_name, ''::text), r.contact_name) AS customer_name,\n    p.full_name AS rescuer_name,\n    v.rating,\n    v.comment,\n    v.created_at\n   FROM ((((customer_request_reviews v\n     JOIN rescue_requests r ON ((r.id = v.request_id)))\n     LEFT JOIN customer_profiles c ON ((c.user_id = v.customer_id)))\n     LEFT JOIN rescue_request_assignments a ON ((a.request_id = r.id)))\n     LEFT JOIN rescuer_profiles p ON ((p.user_id = COALESCE(a.rescuer_id, r.provider_id))))\n  WHERE ( SELECT has_admin_role(ARRAY['super_admin'::text, 'operator'::text, 'support'::text]) AS has_admin_role);",
    "object": "view:public.admin_reviews_view",
    "version": "202610050001"
  }
]$manifest$::jsonb) x
), actual as (
with relations(version, name, is_table) as (values
  ('202610040001', 'admin_profiles', true),
  ('202610040001', 'admin_audit_logs', true),
  ('202610040001', 'admin_notifications', true),
  ('202610040001', 'admin_service_catalog', true),
  ('202610040001', 'admin_services_view', false),
  ('202610040001', 'admin_rescuer_documents_view', false),
  ('202610050001', 'admin_rescue_requests_view', false),
  ('202610050001', 'admin_customers_view', false),
  ('202610050001', 'admin_rescuers_view', false),
  ('202610050001', 'admin_quotes_view', false),
  ('202610050001', 'admin_reviews_view', false)
), function_names(version, qualified_name) as (values
  ('202610040001', 'public.is_admin'),
  ('202610040001', 'public.has_admin_role'),
  ('202610040001', 'private.admin_require_role'),
  ('202610040001', 'public.admin_log_action'),
  ('202610040001', 'private.admin_profile_guard'),
  ('202610040001', 'private.admin_profile_audit'),
  ('202610040001', 'private.admin_notification_guard'),
  ('202610040001', 'private.admin_notification_audit'),
  ('202610040001', 'private.admin_catalog_guard'),
  ('202610040001', 'private.admin_catalog_audit'),
  ('202610040001', 'public.admin_get_dashboard_stats'),
  ('202610040001', 'private.admin_change_rescuer'),
  ('202610040001', 'public.admin_approve_rescuer'),
  ('202610040001', 'public.admin_reject_rescuer'),
  ('202610040001', 'public.admin_block_rescuer'),
  ('202610040001', 'public.admin_cancel_request'),
  ('202610040001', 'public.admin_toggle_service'),
  ('202610050001', 'public.format_display_code'),
  ('202610050001', 'private.assign_display_code'),
  ('202610050001', 'private.rescuer_profile_dto'),
  ('202610050001', 'private.rescuer_assignment_dto'),
  ('202610050001', 'private.rescuer_quote_dto'),
  ('202610050001', 'private.rescuer_available_dto'),
  ('202610050001', 'public.customer_request_display_codes')
), display(table_name, column_name, sequence_name, prefix) as (values
  ('customer_profiles', 'customer_code', 'customer_code_seq', 'KH'),
  ('rescuer_profiles', 'rescuer_code', 'rescuer_code_seq', 'DT'),
  ('rescue_requests', 'request_code', 'request_code_seq', 'CH'),
  ('rescue_quotes', 'quote_code', 'quote_code_seq', 'BG'),
  ('admin_profiles', 'admin_code', 'admin_code_seq', 'AD')
), observations as (
select r.version, 'relation:public.'||r.name as object, (select jsonb_build_object(
  'kind',c.relkind,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,
  'options',coalesce(to_jsonb(c.reloptions),'[]'::jsonb),
  'trusted_owner',not exists(select 1 from pg_roles ro where ro.oid=c.relowner and ro.rolname in ('anon','authenticated','service_role')))
  from pg_class c where c.oid=to_regclass('public.'||r.name)) as actual from relations r
union all
select r.version, 'columns:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,
  'default',pg_get_expr(d.adbin,d.adrelid),'identity',a.attidentity,'generated',a.attgenerated)
  order by a.attnum),'[]'::jsonb) from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
  where a.attrelid=to_regclass('public.'||r.name) and a.attnum>0 and not a.attisdropped) from relations r
union all
select r.version, 'constraints:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',c.conname,'type',c.contype,'definition',pg_get_constraintdef(c.oid,false),
  'validated',c.convalidated,'deferrable',c.condeferrable,'deferred',c.condeferred)
  order by c.conname),'[]'::jsonb) from pg_constraint c where c.conrelid=to_regclass('public.'||r.name))
  from relations r where r.is_table
union all
select r.version, 'indexes:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',c.relname,'definition',pg_get_indexdef(i.indexrelid),'valid',i.indisvalid,
  'ready',i.indisready,'unique',i.indisunique,'primary',i.indisprimary)
  order by c.relname),'[]'::jsonb) from pg_index i join pg_class c on c.oid=i.indexrelid
  where i.indrelid=to_regclass('public.'||r.name)) from relations r where r.is_table
union all
select r.version, 'policies:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',p.polname,'command',p.polcmd,'permissive',p.polpermissive,
  'roles',(select jsonb_agg(case when x=0 then 'PUBLIC' else pg_get_userbyid(x)::text end order by x)
    from unnest(p.polroles) x),'using',pg_get_expr(p.polqual,p.polrelid),
  'check',pg_get_expr(p.polwithcheck,p.polrelid)) order by p.polname),'[]'::jsonb)
  from pg_policy p where p.polrelid=to_regclass('public.'||r.name)) from relations r where r.is_table
union all
select '202610040001', 'policies:public.rescue_services:admin', (select coalesce(jsonb_agg(jsonb_build_object(
  'name',p.polname,'command',p.polcmd,'permissive',p.polpermissive,
  'roles',(select jsonb_agg(case when x=0 then 'PUBLIC' else pg_get_userbyid(x)::text end order by x)
    from unnest(p.polroles) x),'using',pg_get_expr(p.polqual,p.polrelid),
  'check',pg_get_expr(p.polwithcheck,p.polrelid)) order by p.polname),'[]'::jsonb)
  from pg_policy p where p.polrelid=to_regclass('public.rescue_services') and p.polname like 'admin\_%' escape '\')
union all
select r.version, 'triggers:public.'||r.name, (select coalesce(jsonb_agg(jsonb_build_object(
  'name',t.tgname,'definition',regexp_replace(pg_get_triggerdef(t.oid,false),'EXECUTE FUNCTION [^(]+',
    'EXECUTE FUNCTION '||(select format('%I.%I',n.nspname,p.proname) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.oid=t.tgfoid)),
  'enabled',t.tgenabled)
  order by t.tgname),'[]'::jsonb) from pg_trigger t where t.tgrelid=to_regclass('public.'||r.name) and not t.tgisinternal)
  from relations r where r.is_table
union all
select r.version, 'view:public.'||r.name, (select to_jsonb(pg_get_viewdef(c.oid,false))
  from pg_class c where c.oid=to_regclass('public.'||r.name) and c.relkind='v') from relations r where not r.is_table
union all
select r.version, 'acl:public.'||r.name, (select jsonb_build_object(
  'explicit_api_acl',(select coalesce(jsonb_agg(jsonb_build_object('role',case when e.grantee=0 then 'PUBLIC' else pg_get_userbyid(e.grantee)::text end,
    'privilege',e.privilege_type,'grantable',e.is_grantable) order by e.grantee,e.privilege_type),'[]'::jsonb)
    from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) e
    where e.grantee=0 or e.grantee in (select oid from pg_roles where rolname in ('anon','authenticated'))),
  'column_api_acl',(select coalesce(jsonb_agg(jsonb_build_object('column',a.attname,
    'role',case when e.grantee=0 then 'PUBLIC' else pg_get_userbyid(e.grantee)::text end,
    'privilege',e.privilege_type,'grantable',e.is_grantable) order by a.attnum,e.grantee,e.privilege_type),'[]'::jsonb)
    from pg_attribute a cross join lateral aclexplode(a.attacl) e
    where a.attrelid=c.oid and not a.attisdropped and (e.grantee=0 or e.grantee in (select oid from pg_roles where rolname in ('anon','authenticated')))),
  'effective_api_acl',(select jsonb_agg(jsonb_build_object('role',ro.rolname,'privilege',pr,
    'allowed',has_table_privilege(ro.oid,c.oid,pr)) order by ro.rolname,pr)
    from pg_roles ro cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) pr
    where ro.rolname in ('anon','authenticated')))
  from pg_class c where c.oid=to_regclass('public.'||r.name)) from relations r
union all
select f.version, 'function:'||f.qualified_name, (select coalesce(jsonb_agg(jsonb_build_object(
  'signature',n.nspname||'.'||p.proname||'('||oidvectortypes(p.proargtypes)||')',
  'arguments',pg_get_function_arguments(p.oid),'result',pg_get_function_result(p.oid),
  'language',l.lanname,'definer',p.prosecdef,'volatility',p.provolatile,'strict',p.proisstrict,
  'config',coalesce(to_jsonb(p.proconfig),'[]'::jsonb),'body_sha256',encode(sha256(convert_to(replace(p.prosrc,E'\r\n',E'\n'),'UTF8')),'hex'),
  'trusted_owner',not exists(select 1 from pg_roles ro where ro.oid=p.proowner and ro.rolname in ('anon','authenticated','service_role')),
  'public_execute',exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) e where e.grantee=0 and e.privilege_type='EXECUTE'),
  'anon_execute',has_function_privilege((select oid from pg_roles where rolname='anon'),p.oid,'EXECUTE'),
  'authenticated_execute',has_function_privilege((select oid from pg_roles where rolname='authenticated'),p.oid,'EXECUTE'),
  'api_execute_grant_option',exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) e
    where e.is_grantable and (e.grantee=0 or e.grantee in (select oid from pg_roles where rolname in ('anon','authenticated')))))
  order by p.oid),'[]'::jsonb) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
  where n.nspname||'.'||p.proname=f.qualified_name and p.prokind='f') from function_names f
union all
select '202610050001', 'display_column:public.'||x.table_name||'.'||x.column_name, (select jsonb_build_object(
  'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid),
  'identity',a.attidentity,'generated',a.attgenerated) from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
  where a.attrelid=to_regclass('public.'||x.table_name) and a.attname=x.column_name and not a.attisdropped) from display x
union all
select '202610050001', 'display_constraint:public.'||x.table_name, (select jsonb_build_object(
  'definition',pg_get_constraintdef(c.oid,false),'validated',c.convalidated)
  from pg_constraint c where c.conrelid=to_regclass('public.'||x.table_name) and c.conname=x.table_name||'_'||x.column_name||'_format') from display x
union all
select '202610050001', 'display_index:public.'||x.table_name, (select jsonb_build_object(
  'definition',pg_get_indexdef(i.indexrelid),'valid',i.indisvalid,'ready',i.indisready,'unique',i.indisunique)
  from pg_index i join pg_class c on c.oid=i.indexrelid
  where i.indrelid=to_regclass('public.'||x.table_name) and c.relname=x.table_name||'_'||x.column_name||'_uidx') from display x
union all
select '202610050001', 'display_trigger:public.'||x.table_name, (select jsonb_build_object(
  'definition',regexp_replace(pg_get_triggerdef(t.oid,false),'EXECUTE FUNCTION [^(]+',
    'EXECUTE FUNCTION '||(select format('%I.%I',n.nspname,p.proname) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.oid=t.tgfoid)),
  'enabled',t.tgenabled)
  from pg_trigger t where t.tgrelid=to_regclass('public.'||x.table_name) and t.tgname=x.table_name||'_display_code' and not t.tgisinternal) from display x
union all
select '202610050001', 'sequence:public.'||x.sequence_name, (select jsonb_build_object(
  'type',format_type(s.seqtypid,null),'start',s.seqstart::text,'increment',s.seqincrement::text,'min',s.seqmin::text,
  'max',s.seqmax::text,'cache',s.seqcache::text,'cycle',s.seqcycle,
  'api_acl',(select jsonb_agg(jsonb_build_object('role',ro.rolname,'privilege',pr,
    'allowed',has_sequence_privilege(ro.oid,s.seqrelid,pr)) order by ro.rolname,pr)
    from pg_roles ro cross join unnest(array['USAGE','SELECT','UPDATE']) pr where ro.rolname in ('anon','authenticated')),
  'public_acl',exists(select 1 from aclexplode(coalesce(c.relacl,acldefault('S',c.relowner))) e where e.grantee=0),
  'trusted_owner',not exists(select 1 from pg_roles ro where ro.oid=c.relowner and ro.rolname in ('anon','authenticated','service_role')))
  from pg_sequence s join pg_class c on c.oid=s.seqrelid where s.seqrelid=to_regclass('public.'||x.sequence_name)) from display x
)
select version, object, actual from observations), comparisons as (
  select e.version,e.object,e.expected,a.actual from expected e left join actual a using(version,object)
  union all
  select '202610050001'::text as version, 'backfill:public.customer_profiles'::text as object,
    jsonb_build_object('invalid',0,'duplicates',0,'sequence_covers_existing_codes',true) as expected,
    case when exists(select 1 from pg_class where oid=to_regclass('public.customer_profiles') and relkind in ('r','p'))
      and exists(select 1 from pg_class where oid=to_regclass('public.customer_code_seq') and relkind='S')
      and exists(select 1 from pg_attribute where attrelid=to_regclass('public.customer_profiles') and attname='customer_code'
        and atttypid='text'::regtype and not attisdropped)
    then (select jsonb_build_object('invalid',(d->>'invalid')::bigint,'duplicates',(d->>'duplicates')::bigint,
      'sequence_covers_existing_codes',(s->>'last_value')::numeric >= (d->>'maximum')::numeric
        and ((s->>'is_called')::boolean or (s->>'last_value')::numeric > (d->>'maximum')::numeric))
      from (select ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''rows'',count(*),''invalid'',count(*) filter(where
    case when customer_code ~ ''^KH-[0-9]{6,}$'' then substring(customer_code from 4)::numeric < 1 else true end),
    ''duplicates'',count(*)-count(distinct customer_code),
    ''maximum'',coalesce(max(case when customer_code ~ ''^KH-[0-9]{6,}$'' then substring(customer_code from 4)::numeric else 0 end),0)) as result from public.customer_profiles',false,true,'')))[1]::text)::jsonb d,
        ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called) as result from public.customer_code_seq',false,true,'')))[1]::text)::jsonb s) z)
    else null end as actual
  union all
  select '202610050001'::text as version, 'backfill:public.rescuer_profiles'::text as object,
    jsonb_build_object('invalid',0,'duplicates',0,'sequence_covers_existing_codes',true) as expected,
    case when exists(select 1 from pg_class where oid=to_regclass('public.rescuer_profiles') and relkind in ('r','p'))
      and exists(select 1 from pg_class where oid=to_regclass('public.rescuer_code_seq') and relkind='S')
      and exists(select 1 from pg_attribute where attrelid=to_regclass('public.rescuer_profiles') and attname='rescuer_code'
        and atttypid='text'::regtype and not attisdropped)
    then (select jsonb_build_object('invalid',(d->>'invalid')::bigint,'duplicates',(d->>'duplicates')::bigint,
      'sequence_covers_existing_codes',(s->>'last_value')::numeric >= (d->>'maximum')::numeric
        and ((s->>'is_called')::boolean or (s->>'last_value')::numeric > (d->>'maximum')::numeric))
      from (select ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''rows'',count(*),''invalid'',count(*) filter(where
    case when rescuer_code ~ ''^DT-[0-9]{6,}$'' then substring(rescuer_code from 4)::numeric < 1 else true end),
    ''duplicates'',count(*)-count(distinct rescuer_code),
    ''maximum'',coalesce(max(case when rescuer_code ~ ''^DT-[0-9]{6,}$'' then substring(rescuer_code from 4)::numeric else 0 end),0)) as result from public.rescuer_profiles',false,true,'')))[1]::text)::jsonb d,
        ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called) as result from public.rescuer_code_seq',false,true,'')))[1]::text)::jsonb s) z)
    else null end as actual
  union all
  select '202610050001'::text as version, 'backfill:public.rescue_requests'::text as object,
    jsonb_build_object('invalid',0,'duplicates',0,'sequence_covers_existing_codes',true) as expected,
    case when exists(select 1 from pg_class where oid=to_regclass('public.rescue_requests') and relkind in ('r','p'))
      and exists(select 1 from pg_class where oid=to_regclass('public.request_code_seq') and relkind='S')
      and exists(select 1 from pg_attribute where attrelid=to_regclass('public.rescue_requests') and attname='request_code'
        and atttypid='text'::regtype and not attisdropped)
    then (select jsonb_build_object('invalid',(d->>'invalid')::bigint,'duplicates',(d->>'duplicates')::bigint,
      'sequence_covers_existing_codes',(s->>'last_value')::numeric >= (d->>'maximum')::numeric
        and ((s->>'is_called')::boolean or (s->>'last_value')::numeric > (d->>'maximum')::numeric))
      from (select ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''rows'',count(*),''invalid'',count(*) filter(where
    case when request_code ~ ''^CH-[0-9]{6,}$'' then substring(request_code from 4)::numeric < 1 else true end),
    ''duplicates'',count(*)-count(distinct request_code),
    ''maximum'',coalesce(max(case when request_code ~ ''^CH-[0-9]{6,}$'' then substring(request_code from 4)::numeric else 0 end),0)) as result from public.rescue_requests',false,true,'')))[1]::text)::jsonb d,
        ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called) as result from public.request_code_seq',false,true,'')))[1]::text)::jsonb s) z)
    else null end as actual
  union all
  select '202610050001'::text as version, 'backfill:public.rescue_quotes'::text as object,
    jsonb_build_object('invalid',0,'duplicates',0,'sequence_covers_existing_codes',true) as expected,
    case when exists(select 1 from pg_class where oid=to_regclass('public.rescue_quotes') and relkind in ('r','p'))
      and exists(select 1 from pg_class where oid=to_regclass('public.quote_code_seq') and relkind='S')
      and exists(select 1 from pg_attribute where attrelid=to_regclass('public.rescue_quotes') and attname='quote_code'
        and atttypid='text'::regtype and not attisdropped)
    then (select jsonb_build_object('invalid',(d->>'invalid')::bigint,'duplicates',(d->>'duplicates')::bigint,
      'sequence_covers_existing_codes',(s->>'last_value')::numeric >= (d->>'maximum')::numeric
        and ((s->>'is_called')::boolean or (s->>'last_value')::numeric > (d->>'maximum')::numeric))
      from (select ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''rows'',count(*),''invalid'',count(*) filter(where
    case when quote_code ~ ''^BG-[0-9]{6,}$'' then substring(quote_code from 4)::numeric < 1 else true end),
    ''duplicates'',count(*)-count(distinct quote_code),
    ''maximum'',coalesce(max(case when quote_code ~ ''^BG-[0-9]{6,}$'' then substring(quote_code from 4)::numeric else 0 end),0)) as result from public.rescue_quotes',false,true,'')))[1]::text)::jsonb d,
        ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called) as result from public.quote_code_seq',false,true,'')))[1]::text)::jsonb s) z)
    else null end as actual
  union all
  select '202610050001'::text as version, 'backfill:public.admin_profiles'::text as object,
    jsonb_build_object('invalid',0,'duplicates',0,'sequence_covers_existing_codes',true) as expected,
    case when exists(select 1 from pg_class where oid=to_regclass('public.admin_profiles') and relkind in ('r','p'))
      and exists(select 1 from pg_class where oid=to_regclass('public.admin_code_seq') and relkind='S')
      and exists(select 1 from pg_attribute where attrelid=to_regclass('public.admin_profiles') and attname='admin_code'
        and atttypid='text'::regtype and not attisdropped)
    then (select jsonb_build_object('invalid',(d->>'invalid')::bigint,'duplicates',(d->>'duplicates')::bigint,
      'sequence_covers_existing_codes',(s->>'last_value')::numeric >= (d->>'maximum')::numeric
        and ((s->>'is_called')::boolean or (s->>'last_value')::numeric > (d->>'maximum')::numeric))
      from (select ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''rows'',count(*),''invalid'',count(*) filter(where
    case when admin_code ~ ''^AD-[0-9]{6,}$'' then substring(admin_code from 4)::numeric < 1 else true end),
    ''duplicates'',count(*)-count(distinct admin_code),
    ''maximum'',coalesce(max(case when admin_code ~ ''^AD-[0-9]{6,}$'' then substring(admin_code from 4)::numeric else 0 end),0)) as result from public.admin_profiles',false,true,'')))[1]::text)::jsonb d,
        ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called) as result from public.admin_code_seq',false,true,'')))[1]::text)::jsonb s) z)
    else null end as actual
  union all
  select '202610040001','catalog_seed_mappings',
    '{"required_seed_mappings":true,"every_service_has_catalog_entry":true}'::jsonb,
    case when exists(select 1 from pg_class where oid=to_regclass('public.admin_service_catalog') and relkind='r')
      and exists(select 1 from pg_class where oid=to_regclass('public.rescue_services') and relkind='r')
      and (select count(*) from pg_attribute where attrelid=to_regclass('public.admin_service_catalog')
        and attname in ('service_code','admin_code') and atttypid='text'::regtype and not attisdropped)=2
      and exists(select 1 from pg_attribute where attrelid=to_regclass('public.rescue_services')
        and attname='code' and atttypid='text'::regtype and not attisdropped)
    then ((xpath('/row/result/text()',query_to_xml('select jsonb_build_object(''required_seed_mappings'',not exists(
  select 1 from (values (''towing'',''SRV-TOW-01''),(''battery'',''SRV-BAT-02''),(''tire'',''SRV-TYR-03''),
    (''fuel'',''SRV-FUL-04''),(''locksmith'',''SRV-LCK-05''),(''mechanic'',''SRV-MEC-06'')) e(service_code,admin_code)
  where not exists(select 1 from public.admin_service_catalog a where a.service_code=e.service_code and a.admin_code=e.admin_code)),
  ''every_service_has_catalog_entry'',not exists(select 1 from public.rescue_services s
    where not exists(select 1 from public.admin_service_catalog a where a.service_code=s.code))) as result',false,true,'')))[1]::text)::jsonb else null end
  union all
  select v,'verification_role:catalog_and_data_visibility','true'::jsonb,
    to_jsonb(exists(select 1 from pg_roles where rolname=current_user and (rolsuper or rolbypassrls)))
    from unnest(array['202610040001','202610050001']) v
), checks as (
  select *,expected is not distinct from actual as passed from comparisons
), summary as (
  select coalesce(bool_and(passed) filter(where version='202610040001'),false) as match040,
    coalesce(bool_and(passed) filter(where version='202610050001'),false) as match050,
    count(*) as checks,count(*) filter(where not passed) as failures from checks
)
select row_kind,version,object,result,passed,details from (
  select 1 as sort,'OBJECT'::text as row_kind,version,object,case when passed then 'PASS' else 'FAIL' end as result,passed,
    case when passed then '{}'::jsonb else jsonb_build_object('expected',expected,'actual',actual) end as details from checks
  union all
  select 2,'SUMMARY','202610040001','040001_SCHEMA_MATCH',match040::text,match040,'{}'::jsonb from summary
  union all
  select 2,'SUMMARY','202610050001','050001_SCHEMA_MATCH',match050::text,match050,'{}'::jsonb from summary
  union all
  select 3,'OVERALL',null,'HISTORY_SCHEMA_VERIFICATION',case when match040 and match050 then 'PASS' else 'FAIL' end,
    match040 and match050,jsonb_build_object('checks',checks,'failures',failures,
      'history_repair_commands',case when match040 and match050 then jsonb_build_array(
        'supabase migration repair --status applied 202610040001',
        'supabase migration repair --status applied 202610050001') else '[]'::jsonb end,
      'commands_executed',false) from summary
  union all
  select 0,'CONTEXT',null,'database_and_read_only_transaction','INFO',null,
    jsonb_build_object('database',current_database(),'server_version',current_setting('server_version'),
      'read_only',current_setting('transaction_read_only'),'schema_check_is_not_proof_of_application_timestamp',true)
  union all
  select 0,'CONTEXT',null,'recorded_migration_history','INFO',null,
    coalesce((select jsonb_agg(jsonb_build_object('version',version,'name',name) order by version)
      from supabase_migrations.schema_migrations where version in ('202610040001','202610050001','202610130003')),'[]'::jsonb)
  union all
  select 0,'CONTEXT',null,'service_role_execute_not_revoked_by_original_migrations','INFO',null,
    coalesce((select jsonb_agg(jsonb_build_object('signature',n.nspname||'.'||p.proname||'('||oidvectortypes(p.proargtypes)||')',
      'execute',has_function_privilege(r.oid,p.oid,'EXECUTE')) order by n.nspname,p.proname)
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join pg_roles r
      where r.rolname='service_role' and n.nspname||'.'||p.proname in (
        'public.is_admin',
        'public.has_admin_role',
        'private.admin_require_role',
        'public.admin_log_action',
        'private.admin_profile_guard',
        'private.admin_profile_audit',
        'private.admin_notification_guard',
        'private.admin_notification_audit',
        'private.admin_catalog_guard',
        'private.admin_catalog_audit',
        'public.admin_get_dashboard_stats',
        'private.admin_change_rescuer',
        'public.admin_approve_rescuer',
        'public.admin_reject_rescuer',
        'public.admin_block_rescuer',
        'public.admin_cancel_request',
        'public.admin_toggle_service',
        'public.format_display_code',
        'private.assign_display_code',
        'private.rescuer_profile_dto',
        'private.rescuer_assignment_dto',
        'private.rescuer_quote_dto',
        'private.rescuer_available_dto',
        'public.customer_request_display_codes')),'[]'::jsonb)
) report order by sort,version,object;
rollback;
