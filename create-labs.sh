#!/bin/bash
set -e

echo "Creating CKAD Exam Simulator structure..."

mkdir -p questions

########################
# ROOT FILES
########################

cat > run.sh <<'EOF'
#!/bin/bash
set -e

QUESTION=$1

if [ -z "$QUESTION" ]; then
  echo "Usage: ./run.sh q01"
  ls questions
  exit 1
fi

MATCH=$(find questions -maxdepth 1 -type d -name "${QUESTION}-*" | head -n 1)

if [ -z "$MATCH" ]; then
  echo "Question not found"
  exit 1
fi

chmod +x "$MATCH/setup.sh"
"$MATCH/setup.sh"

echo ""
echo "======================"
echo "QUESTION"
echo "======================"
cat "$MATCH/question.md"
EOF

cat > reset-all.sh <<'EOF'
#!/bin/bash
for d in questions/*; do
  if [ -f "$d/reset.sh" ]; then
    chmod +x "$d/reset.sh"
    "$d/reset.sh" || true
  fi
done
echo "Reset completed"
EOF

chmod +x run.sh reset-all.sh

########################
# FUNCTION
########################

create_q() {
  NAME=$1
  TITLE=$2

  mkdir -p questions/$NAME

  cat > questions/$NAME/question.md <<EOF
# $TITLE

## Task

Refer to original CKAD question.
EOF

  cat > questions/$NAME/setup.sh <<EOF
#!/bin/bash
set -e
echo "Environment ready for $NAME"
EOF

  cat > questions/$NAME/reset.sh <<EOF
#!/bin/bash
echo "Reset for $NAME"
EOF

  chmod +x questions/$NAME/*.sh
}

########################
# CREATE ALL QUESTIONS
########################

create_q q01-rbac-scraper "Q01 RBAC Scraper"
create_q q02-cronjob-pi "Q02 CronJob"
create_q q03-update-deployment-labels-service "Q03 Deployment Labels + Service"
create_q q04-container-security-context "Q04 Security Context"
create_q q05-fix-api-deprecation "Q05 Legacy App"
create_q q06-limit-cpu-memory-requests "Q06 CPU Memory"
create_q q07-readiness-probe "Q07 Readiness Probe"
create_q q08-upgrade-rollback "Q08 Upgrade Rollback"
create_q q09-create-ingress "Q09 Ingress"
create_q q10-rbac-authorization "Q10 RBAC Fix"
create_q q11-dockerfile-build-export "Q11 Dockerfile"
create_q q12-secret-postgres "Q12 Secret Postgres"
create_q q13-ingress-troubleshooting "Q13 Ingress Fix"
create_q q14-networkpolicy-existing "Q14 NetworkPolicy"
create_q q15-memory-request-limit "Q15 Memory"
create_q q16-modify-container-name-image "Q16 Modify Container"
create_q q17-canary-deployment "Q17 Canary"
create_q q18-secret-env "Q18 Secret Env"
create_q q19-deployment-env-var "Q19 Deployment Env"

echo ""
echo "=================================="
echo "ALL 19 QUESTIONS CREATED"
echo "=================================="
echo ""
echo "Next steps:"
echo "chmod +x run.sh"
echo "./run.sh q01"
