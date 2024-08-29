import argparse

from godot_rl.wrappers.sample_factory_wrapper import sample_factory_enjoy, sample_factory_training

def str2bool(v):
    if isinstance(v, bool):
        return v
    if isinstance(v, str) and v.lower() in ("true",):
        return True
    elif isinstance(v, str) and v.lower() in ("false",):
        return False
    else:
        raise argparse.ArgumentTypeError("Boolean value expected")

def get_args():
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--env_path", default=None, type=str, help="Godot binary to use")
    parser.add_argument("--eval", default=False, action="store_true", help="whether to eval the model")
    parser.add_argument("--speedup", default=1, type=int, help="whether to speed up the physics in the env")
    parser.add_argument("--seed", default=0, type=int, help="environment seed")
    parser.add_argument("--export", default=True, help="whether to export the model")
    parser.add_argument("--active_agent", default=None, type=int, help="3 means both agents are training.")
    parser.add_argument("--viz", default=False, action="store_true", help="Whether to visualize one process")
    parser.add_argument("--static_policy_mapping", default=True, type=str2bool)
    parser.add_argument("--reward_config", default=None, type=str)
    parser.add_argument(
        "--experiment_dir",
        default="logs/sf",
        type=str,
        help="The name of the experiment directory, in which the tensorboard logs are getting stored",
    )
    parser.add_argument(
        "--experiment_name",
        default="experiment",
        type=str,
        help="The name of the experiment, which will be displayed in tensorboard. ",
    )

    return parser.parse_known_args()


def main():
    args, extras = get_args()
    if args.eval:
        sample_factory_enjoy(args, extras)
    else:
        sample_factory_training(args, extras)


if __name__ == "__main__":
    main()
