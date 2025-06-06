# Copyright (c) 2020-2025, NVIDIA CORPORATION.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
TRANSFORMERS_OFFLINE=1 \
    coverage run -a --data-file=/workspace/.coverage --source=/workspace/nemo scripts/vlm/qwen2vl_finetune.py \
     --num_nodes 1 \
     --devices=2 \
     --data_type=qwen2vl \
     --data_path=/home/TestData/tiny_datasets/qwen2vl/preloaded.json \
     --image_folder "/home/TestData/tiny_datasets/qwen2vl/images" \
     --video_folder "/home/TestData/tiny_datasets/qwen2vl/videos" \
     --max_sequence_length=38400 \
     --projector_type="mcore_mlp" \
     --tp_size 2 --pp_size 1 \
     --gbs 4 --mbs 1 \
     --max_steps=4 \
     --log_dir=/tmp/nemo2_qwen2vl_results/$RUN_ID
