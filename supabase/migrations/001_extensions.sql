-- Phase 1A: extensions required for UUID generation (gen_random_uuid).
create extension if not exists pgcrypto with schema extensions;
