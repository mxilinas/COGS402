proj_dir=/home/michael/cogs

policy_index=$2
active_agent=$3

# if [ "$policy_index" -eq 0 ]; then
#     active_agent=1
# else
#     active_agent=0
# fi

args=(
"--env gdrl"
"--env_path ${proj_dir}/main.x86_64"
"--train_dir ${proj_dir}/logs/sf"

"--max_num_frames 6400"
"--eval"
"--no_render"
"--active_agent ${active_agent}"
"--policy_index ${policy_index}"
"--export false"
"--env_agents 1"
"--num_policies 1"
"--num_envs_per_worker 1"
"--worker_num_splits 1"
"--batched_sampling true"
"--viz"
"--speedup=1"
)

# User must provide both experiment name and active agent.
python ${proj_dir}/scripts/sf.py ${args[@]} "--experiment_name=$1" "--reward_config=${proj_dir}/configs/$4.ini"

