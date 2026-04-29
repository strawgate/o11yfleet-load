default:
    @just --list

check:
    bash -n scripts/*.sh
    O11YFLEET_API_URL=http://localhost:8787 RUN_ID=local-check JOB_INDEX=0 INSTANCE=0 GLOBAL_INDEX=0 SERVICE_NAME=o11yfleet-load-check COLLECTION_INTERVAL=60s scripts/generate-collector-config.sh runtime/check.yaml fp_enroll_test-token 00000000-0000-5000-8000-000000000000
    test -s runtime/check.yaml

clean:
    rm -rf logs runtime results supervisord.ini run.env

