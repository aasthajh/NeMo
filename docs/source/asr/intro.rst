Automatic Speech Recognition (ASR)
==================================

Automatic Speech Recognition (ASR), also known as Speech To Text (STT), refers to the problem of automatically transcribing spoken language.
You can use NeMo to transcribe speech using open-sourced pretrained models in :ref:`14+ languages <asr-checkpoint-list-by-language>`, or :doc:`train your own<./examples/kinyarwanda_asr>` ASR models.



Transcribe speech with 3 lines of code
----------------------------------------
After :ref:`installing NeMo<installation>`, you can transcribe an audio file as follows:

.. code-block:: python

    import nemo.collections.asr as nemo_asr
    asr_model = nemo_asr.models.ASRModel.from_pretrained("stt_en_fastconformer_transducer_large")
    transcript = asr_model.transcribe(["path/to/audio_file.wav"])[0].text

Obtain timestamps
^^^^^^^^^^^^^^^^^

Obtaining char(token), word or segment timestamps is also possible with NeMo ASR Models. 

Currently, timestamps are available for Parakeet Models with all types of decoders (CTC/RNNT/TDT). Support for AED models would be added soon.

There are two ways to obtain timestamps:
1. By using the `timestamps=True` flag in the `transcribe` method.
2. For more control over the timestamps, you can update the decoding config to mention type of timestamps (char, word, segment) and also specify the segment seperators or word seperator for segment and word level timestamps.

With the `timestamps=True` flag, you can obtain timestamps for each character in the transcription as follows:

.. code-block:: python
    
    # import nemo_asr and instantiate asr_model as above
    import nemo.collections.asr as nemo_asr
    asr_model = nemo_asr.models.ASRModel.from_pretrained("nvidia/parakeet-tdt_ctc-110m")

    # specify flag `timestamps=True`
    hypotheses = asr_model.transcribe(["path/to/audio_file.wav"], timestamps=True)

    # by default, timestamps are enabled for char, word and segment level
    word_timestamps = hypotheses[0].timestamp['word'] # word level timestamps for first sample
    segment_timestamps = hypotheses[0].timestamp['segment'] # segment level timestamps
    char_timestamps = hypotheses[0].timestamp['char'] # char level timestamps

    for stamp in segment_timestamps:
        print(f"{stamp['start']}s - {stamp['end']}s : {stamp['segment']}")

    # segment level timestamps (if model supports Punctuation and Capitalization, segment level timestamps are displayed based on punctuation otherwise complete transcription is considered as a single segment)
    
For more control over the timestamps, you can update the decoding config to mention type of timestamps (char, word, segment) and also specify the segment seperators or word seperator for segment and word level timestamps as follows:

.. code-block:: python

    # import nemo_asr and instantiate asr_model as above
    import nemo.collections.asr as nemo_asr
    asr_model = nemo_asr.models.ASRModel.from_pretrained("stt_en_fastconformer_transducer_large")

    # update decoding config to preserve alignments and compute timestamps
    # if necessary also update the segment seperators or word seperator for segment and word level timestamps
    from omegaconf import OmegaConf, open_dict
    decoding_cfg = asr_model.cfg.decoding
    with open_dict(decoding_cfg):
        decoding_cfg.preserve_alignments = True
        decoding_cfg.compute_timestamps = True
        decoding_cfg.segment_seperators = [".", "?", "!"]
        decoding_cfg.word_seperator = " "
        asr_model.change_decoding_strategy(decoding_cfg)

    # specify flag `return_hypotheses=True``
    hypotheses = asr_model.transcribe(["path/to/audio_file.wav"], return_hypotheses=True)

    timestamp_dict = hypotheses[0].timestamp # extract timestamps from hypothesis of first (and only) audio file
    print("Hypothesis contains following timestamp information :", list(timestamp_dict.keys()))

    # For a FastConformer model, you can display the word timestamps as follows:
    # 80ms is duration of a timestamp at output of the Conformer
    time_stride = 8 * asr_model.cfg.preprocessor.window_stride

    word_timestamps = timestamp_dict['word']
    segment_timestamps = timestamp_dict['segment']

    for stamp in word_timestamps:
        start = stamp['start_offset'] * time_stride
        end = stamp['end_offset'] * time_stride
        word = stamp['char'] if 'char' in stamp else stamp['word']

        print(f"Time : {start:0.2f} - {end:0.2f} - {word}")

    for stamp in segment_timestamps:
        start = stamp['start_offset'] * time_stride
        end = stamp['end_offset'] * time_stride
        segment = stamp['segment']

        print(f"Time : {start:0.2f} - {end:0.2f} - {segment}")

Transcribe speech via command line
----------------------------------
You can also transcribe speech via the command line using the following `script <https://github.com/NVIDIA/NeMo/blob/main/examples/asr/transcribe_speech.py>`_, for example:

.. code-block:: bash

    python <path_to_NeMo>/blob/main/examples/asr/transcribe_speech.py \
        pretrained_name="stt_en_fastconformer_transducer_large" \
        audio_dir=<path_to_audio_dir> # path to dir containing audio files to transcribe

The script will save all transcriptions in a JSONL file where each line corresponds to an audio file in ``<audio_dir>``.
This file will correspond to a format that NeMo commonly uses for saving model predictions, and also for storing
input data for training and evaluation. You can learn more about the format that NeMo uses for these files
(which we refer to as "manifest files") :ref:`here<section-with-manifest-format-explanation>`.

You can also specify the files to be transcribed inside a manifest file, and pass that in using the argument
``dataset_manifest=<path to manifest specifying audio files to transcribe>`` instead of ``audio_dir``.


Incorporate a language model (LM) to improve ASR transcriptions
---------------------------------------------------------------

You can often get a boost to transcription accuracy by using a Language Model to help choose words that are more likely
to be spoken in a sentence.

You can get a good improvement in transcription accuracy even using a simple N-gram LM.

After :ref:`training <train-ngram-lm>` an N-gram LM, you can use it for transcribing audio as follows:

1. Install the OpenSeq2Seq beam search decoding and KenLM libraries using the `install_beamsearch_decoders script <https://github.com/NVIDIA/NeMo/blob/stable/scripts/asr_language_modeling/ngram_lm/install_beamsearch_decoders.sh>`_.
2. Perform transcription using the `eval_beamsearch_ngram script <https://github.com/NVIDIA/NeMo/blob/stable/scripts/asr_language_modeling/ngram_lm/eval_beamsearch_ngram_ctc.py>`_:

.. code-block:: bash

    python eval_beamsearch_ngram.py nemo_model_file=<path to the .nemo file of the model> \
        input_manifest=<path to the evaluation JSON manifest file \
        kenlm_model_file=<path to the binary KenLM model> \
        beam_width=[<list of the beam widths, separated with commas>] \
        beam_alpha=[<list of the beam alphas, separated with commas>] \
        beam_beta=[<list of the beam betas, separated with commas>] \
        preds_output_folder=<optional folder to store the predictions> \
        probs_cache_file=null \
        decoding_mode=beamsearch_ngram \
        decoding_strategy="<Beam library such as beam, pyctcdecode or flashlight>"

See more information about LM decoding :doc:`here <./asr_language_modeling_and_customization>`.

Use real-time transcription
---------------------------

It is possible to use NeMo to transcribe speech in real-time. We provide tutorial notebooks for `Cache Aware Streaming <https://github.com/NVIDIA/NeMo/blob/main/tutorials/asr/Online_ASR_Microphone_Demo_Cache_Aware_Streaming.ipynb>`_ and `Buffered Streaming <https://github.com/NVIDIA/NeMo/blob/main/tutorials/asr/Online_ASR_Microphone_Demo_Buffered_Streaming.ipynb>`_.

Try different ASR models
------------------------

NeMo offers a variety of open-sourced pretrained ASR models that vary by model architecture:

* **encoder architecture** (FastConformer, Conformer, Citrinet, etc.),
* **decoder architecture** (Transducer, CTC & hybrid of the two),
* **size** of the model (small, medium, large, etc.).

The pretrained models also vary by:

* **language** (English, Spanish, etc., including some **multilingual** and **code-switching** models),
* whether the output text contains **punctuation & capitalization** or not.

The NeMo ASR checkpoints can be found on `HuggingFace <https://huggingface.co/models?library=nemo&sort=downloads&search=nvidia>`_, or on `NGC <https://catalog.ngc.nvidia.com/models?query=nemo&orderBy=weightPopularDESC>`_. All models released by the NeMo team can be found on NGC, and some of those are also available on HuggingFace.

All NeMo ASR checkpoints open-sourced by the NeMo team follow the following naming convention:
``stt_{language}_{encoder name}_{decoder name}_{model size}{_optional descriptor}``.

You can load the checkpoints automatically using the ``ASRModel.from_pretrained()`` class method, for example:

.. code-block:: python

    import nemo.collections.asr as nemo_asr
    # model will be fetched from NGC
    asr_model = nemo_asr.models.ASRModel.from_pretrained("stt_en_fastconformer_transducer_large")
    # if model name is prepended with "nvidia/", the model will be fetched from huggingface
    asr_model = nemo_asr.models.ASRModel.from_pretrained("nvidia/stt_en_fastconformer_transducer_large")
    # you can also load open-sourced NeMo models released by other HF users using:
    # asr_model = nemo_asr.models.ASRModel.from_pretrained("<HF username>/<model name>")

See further documentation about :doc:`loading checkpoints <./results>`, a full :ref:`list <asr-checkpoint-list-by-language>` of models and their :doc:`benchmark scores <./scores>`.

There is also more information about the ASR model architectures available in NeMo :doc:`here <./models>`.


Try out NeMo ASR transcription in your browser
----------------------------------------------
You can try out transcription with a NeMo ASR model without leaving your browser, by using the HuggingFace Space embedded below.

This HuggingFace Space uses `Parakeet TDT 0.6B V2 <https://huggingface.co/spaces/nvidia/parakeet-tdt-0.6b-v2>`__, the latest ASR model from NVIDIA NeMo. It sits at the top of the `HuggingFace OpenASR Leaderboard <https://huggingface.co/spaces/hf-audio/open_asr_leaderboard>`__ at time of writing (May 2nd 2025).

.. raw:: html

    <script
        type="module"
        src="https://gradio.s3-us-west-2.amazonaws.com/5.27.1/gradio.js"
    ></script>

    <gradio-app src="https://nvidia-parakeet-tdt-0-6b-v2.hf.space"></gradio-app>



ASR tutorial notebooks
----------------------
Hands-on speech recognition tutorial notebooks can be found under `the ASR tutorials folder <https://github.com/NVIDIA/NeMo/tree/main/tutorials/asr>`_.
If you are a beginner to NeMo, consider trying out the `ASR with NeMo <https://github.com/NVIDIA/NeMo/blob/main/tutorials/asr/ASR_with_NeMo.ipynb>`_ tutorial.
This and most other tutorials can be run on Google Colab by specifying the link to the notebooks' GitHub pages on Colab.

ASR model configuration
-----------------------
Documentation regarding the configuration files specific to the ``nemo_asr`` models can be found in the :doc:`Configuration Files <./configs>` section.

Preparing ASR datasets
----------------------
NeMo includes preprocessing scripts for several common ASR datasets. The :doc:`Datasets <./datasets>` section contains instructions on
running those scripts. It also includes guidance for creating your own NeMo-compatible dataset, if you have your own data.

NeMo ASR Documentation
----------------------
For more information, see additional sections in the ASR docs on the left-hand-side menu or in the list below:

.. toctree::
   :maxdepth: 1

   models
   datasets
   asr_language_modeling_and_customization
   results
   scores
   configs
   api
   all_chkpt
   examples/kinyarwanda_asr.rst
