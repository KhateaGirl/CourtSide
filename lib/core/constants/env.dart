class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nyoogofpkqpdxnmeqsyv.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im55b29nb2Zwa3FwZHhubWVxc3l2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwOTI0MTksImV4cCI6MjA4ODY2ODQxOX0.hTlYqQBtDHXRe_1_oT78ui2zcqHV5I7R5frcOYVVJx8',
  );
}

