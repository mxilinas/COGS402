proj_dir=/home/michael/cogs

args=(
"--reward_config ${proj_dir}/configs/$1.ini"
"--env gdrl"
"--env_path ${proj_dir}/main.x86_64"
"--train_dir ${proj_dir}/logs/sf"
"--train_for_env_steps=500000"
"--restart_behavior resume"

"--static_policy_mapping true"
"--with_pbt true"
"--use_rnn true"
"--recurrence 32"
"--rollout 32"
"--normalize_input true"
"--env_agents 2"
"--num_policies 2"
"--num_workers 2"
"--num_envs_per_worker 1"
"--worker_num_splits 1"
"--viz"
"--speedup=8"
)

python ${proj_dir}/scripts/sf.py ${args[@]} "--experiment_name=$1"
