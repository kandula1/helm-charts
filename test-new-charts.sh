#!/bin/bash
# ============================================================
# Test all 4 new Helm charts
# Run from the helm-charts repo root:  bash test-new-charts.sh
# ============================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
CHARTS=("k8s-demo-servicemonitor" "k8s-demo-priorityclass" "k8s-demo-securitycontext" "k8s-demo-team-quota")

echo -e "\n${BOLD}${CYAN}========================================${NC}"
echo -e "${BOLD}${CYAN}  Helm Chart Test Suite - 4 New Charts${NC}"
echo -e "${BOLD}${CYAN}========================================${NC}\n"

for CHART in "${CHARTS[@]}"; do
    echo -e "${BOLD}${CYAN}--- Testing: ${CHART} ---${NC}"

    # 1. Lint
    echo -n "  Lint:          "
    LINT_OUTPUT=$(helm lint "charts/${CHART}" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}"
        echo "$LINT_OUTPUT"
        ((FAIL++))
    fi

    # 2. Template (with default empty values)
    echo -n "  Template:      "
    TEMPLATE_OUTPUT=$(helm template "${CHART}" "charts/${CHART}" --namespace demo-prod 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}"
        echo "$TEMPLATE_OUTPUT"
        ((FAIL++))
    fi

    # 3. Template with actual values from ServiceDeployment
    echo -n "  Template+vals: "
    case $CHART in
        k8s-demo-servicemonitor)
            VALUES='--set-json=monitors=[{"name":"demo-app-monitor","selectorLabels":{"monitored-by":"prometheus"},"endpoints":[{"port":"metrics","path":"/metrics","interval":"30s"}],"testApp":{"enabled":true,"image":"nginx","tag":"1.27-alpine","port":80}}]'
            ;;
        k8s-demo-priorityclass)
            VALUES='--set-json=priorityClasses=[{"name":"critical-priority","value":1000000,"description":"Critical workloads","testPod":{"enabled":true}},{"name":"high-priority","value":100000,"description":"Production workloads","testPod":{"enabled":true}},{"name":"low-priority","value":1000,"preemptionPolicy":"Never","description":"Batch jobs","testPod":{"enabled":true}}]'
            ;;
        k8s-demo-securitycontext)
            VALUES='--set-json=apps=[{"name":"hardened-app","image":"nginx","tag":"1.27-alpine","ports":[80],"podSecurityContext":{"runAsNonRoot":true,"runAsUser":101,"runAsGroup":101,"fsGroup":101},"containerSecurityContext":{"readOnlyRootFilesystem":true,"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"testJob":{"enabled":true}}]'
            ;;
        k8s-demo-team-quota)
            VALUES='--set-json=teams=[{"name":"team-frontend","namespace":"team-frontend","quota":{"requestsCpu":"2","requestsMemory":"4Gi","limitsCpu":"4","limitsMemory":"8Gi","maxPods":"20"},"limits":{"defaultCpu":"250m","defaultMemory":"256Mi","defaultRequestCpu":"100m","defaultRequestMemory":"128Mi","maxCpu":"1","maxMemory":"2Gi"},"testPod":{"enabled":true}}]'
            ;;
    esac

    TEMPLATE_VALS_OUTPUT=$(helm template "${CHART}" "charts/${CHART}" --namespace demo-prod "$VALUES" 2>&1)
    if [ $? -eq 0 ]; then
        # Count resources rendered
        RESOURCE_COUNT=$(echo "$TEMPLATE_VALS_OUTPUT" | grep -c "^kind:")
        echo -e "${GREEN}PASS${NC} (${RESOURCE_COUNT} resources rendered)"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC}"
        echo "$TEMPLATE_VALS_OUTPUT"
        ((FAIL++))
    fi

    # 4. Show what resources were rendered
    echo -e "  ${YELLOW}Resources:${NC}"
    echo "$TEMPLATE_VALS_OUTPUT" | grep "^kind:" | sort | uniq -c | while read COUNT KIND; do
        echo -e "    ${COUNT}x ${KIND}"
    done

    echo ""
done

# Summary
echo -e "${BOLD}${CYAN}========================================${NC}"
echo -e "${BOLD}${CYAN}  RESULTS${NC}"
echo -e "${BOLD}${CYAN}========================================${NC}"
echo -e "  ${GREEN}Passed: ${PASS}${NC}"
echo -e "  ${RED}Failed: ${FAIL}${NC}"
TOTAL=$((PASS + FAIL))
echo -e "  Total:  ${TOTAL}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}ALL TESTS PASSED${NC}"
else
    echo -e "  ${RED}${BOLD}SOME TESTS FAILED - fix before deploying${NC}"
fi
echo ""