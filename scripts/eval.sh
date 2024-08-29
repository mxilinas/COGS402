proj_dir=/home/michael/cogs

args=(
"--reward_config ${proj_dir}/configs/$1.ini"
"--static_policy_mapping true"
"--env gdrl"
"--env_path ${proj_dir}/main.x86_64"
"--train_dir ${proj_dir}/logs/sf"

"--with_pbt true"
"--use_rnn true"
"--recurrence 64"
"--rollout 64"

"--viz"
"--speedup=8"
"--no_render"
"--eval"
"--export false"
"--env_agents 2"
"--num_policies 2"
"--num_envs_per_worker 1"
"--worker_num_splits 1"
"--batched_sampling true"
"--viz"
"--speedup=1"
)

python ${proj_dir}/scripts/sf.py ${args[@]} "--experiment_name=$1"
