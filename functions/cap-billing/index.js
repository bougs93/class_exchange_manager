// 예산 초과 시 프로젝트 결제를 자동 중지한다.
//
// 동작: 결제 예산 알림(Pub/Sub) 수신 → 해당 프로젝트의 결제 연결 해제.
// 결제가 끊기면 유료 서비스(Firestore·Storage·Hosting)가 함께 멈추므로,
// "돈 대신 서비스 중단"을 택하는 최후 안전장치다. 복구는 콘솔에서 결제를
// 다시 연결하면 된다.
//
// 주의: 이 함수는 배포된 뒤 결제 계정에 대한 Billing Administrator 권한을
// 함수 서비스 계정에 부여해야 동작한다 (아래 배포手順 참고).
const {CloudBillingClient} = require('@google-cloud/billing');

const billing = new CloudBillingClient();

exports.stopBilling = async message => {
  const projectId =
    process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || '';
  if (!projectId) {
    console.error('프로젝트 ID를 확인할 수 없습니다.');
    return;
  }

  const projectName = `projects/${projectId}`;
  const [billingInfo] = await billing.getProjectBillingInfo({
    name: projectName,
  });

  if (!billingInfo.billingEnabled) {
    console.log(`${projectId}: 이미 결제가 중지된 상태입니다.`);
    return;
  }

  console.warn(`${projectId}: 예산 초과 감지 — 결제를 중지합니다.`);
  await billing.updateProjectBillingInfo({
    name: projectName,
    projectBillingInfo: {billingAccountName: ''},
  });
  console.warn(`${projectId}: 결제 중지 완료.`);
};
