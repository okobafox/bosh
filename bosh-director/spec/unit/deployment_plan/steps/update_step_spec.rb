require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

module Bosh::Director
  describe DeploymentPlan::Steps::UpdateStep do
    subject { DeploymentPlan::Steps::UpdateStep.new(base_job, event_log, deployment_plan, multi_job_updater, cloud) }
    let(:base_job) { Jobs::BaseJob.new }
    let(:event_log) { Bosh::Director::Config.event_log }
    let(:ip_provider) {instance_double('Bosh::Director::DeploymentPlan::IpProvider')}
    let(:skip_drain) {instance_double('Bosh::Director::DeploymentPlan::SkipDrain')}

    let(:deployment_plan) do
      instance_double('Bosh::Director::DeploymentPlan::Planner',
        update_stemcell_references!: nil,
        persist_updates!: nil,
        jobs_starting_on_deploy: [],
        instance_plans_with_missing_vms: [],
        ip_provider: ip_provider,
        skip_drain: skip_drain,
        recreate: false,
        unneeded_instances: [Models::Instance.make(vm_cid: 'vm-cid-1')]
      )
    end
    let(:cloud) { instance_double('Bosh::Cloud', delete_vm: nil) }
    let(:manifest) { ManifestHelper.default_legacy_manifest }
    let(:releases) { [] }
    let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater', run: nil) }
    let(:agent_client) { instance_double(AgentClient, drain: 0, stop: nil) }

    before do
      allow(base_job).to receive(:logger).and_return(logger)
      allow(base_job).to receive(:track_and_log).and_yield
      allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(true)
      allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud)
      allow(AgentClient).to receive(:with_vm).and_return(agent_client)
      fake_app
    end

    describe '#perform' do
      let(:job1) { instance_double('Bosh::Director::DeploymentPlan::Job', instances: [instance1, instance2]) }
      let(:job2) { instance_double('Bosh::Director::DeploymentPlan::Job', instances: [instance3]) }
      let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
      let(:instance3) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

      it 'runs deployment plan update stages in the correct order' do
        allow(event_log).to receive(:track).and_yield
        allow(deployment_plan).to receive(:jobs_starting_on_deploy).with(no_args).and_return([job1, job2])

        expect(base_job).to receive(:task_checkpoint).with(no_args).ordered
        expect(multi_job_updater).to receive(:run).with(base_job, deployment_plan, [job1, job2]).ordered
        expect(deployment_plan).to receive(:persist_updates!).ordered
        subject.perform

        expect(Models::Instance.find(vm_cid: 'vm-cid-1')).to be_nil
      end

      context 'when perform fails' do
        it 'still updates the stemcell references' do
          expect(deployment_plan).to receive(:update_stemcell_references!)
          error = RuntimeError.new('oops')
          expect(cloud).to receive(:delete_vm).and_raise(error)

          expect{
            subject.perform
          }.to raise_error(error)
        end
      end
    end
  end
end
