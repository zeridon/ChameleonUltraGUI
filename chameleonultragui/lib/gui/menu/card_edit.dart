import 'package:chameleonultragui/helpers/mifare_ultralight/general.dart';
import 'package:flutter/material.dart';
import 'package:chameleonultragui/helpers/general.dart';
import 'package:chameleonultragui/sharedprefsprovider.dart';
import 'package:chameleonultragui/bridge/chameleon.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chameleonultragui/main.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:chameleonultragui/helpers/mifare_classic/general.dart';

// Localizations
import 'package:chameleonultragui/generated/i18n/app_localizations.dart';

class CardEditMenu extends StatefulWidget {
  final CardSave tagSave;
  final bool isNew;

  const CardEditMenu({super.key, required this.tagSave, this.isNew = false});

  @override
  CardEditMenuState createState() => CardEditMenuState();
}

class CardEditMenuState extends State<CardEditMenu> {
  TagType selectedType = TagType.unknown;
  TextEditingController nameController = TextEditingController();
  TextEditingController uidController = TextEditingController();
  TextEditingController sakController = TextEditingController();
  TextEditingController atqaController = TextEditingController();
  TextEditingController atsController = TextEditingController();
  TextEditingController ultralightVersionController = TextEditingController();
  TextEditingController ultralightSignatureController = TextEditingController();
  List<TextEditingController> ultralightCounterControllers = [];
  Color pickerColor = Colors.deepOrange;
  Color currentColor = Colors.deepOrange;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String originalUid = '';
  String originalSak = '';
  String originalAtqa = '';

  @override
  void initState() {
    super.initState();
    selectedType = widget.tagSave.tag;
    uidController.text = widget.tagSave.uid;
    sakController.text = bytesToHexSpace(u8ToBytes(widget.tagSave.sak));
    atqaController.text = bytesToHexSpace(widget.tagSave.atqa);
    atsController.text = bytesToHexSpace(widget.tagSave.ats);
    ultralightVersionController.text =
        bytesToHexSpace(widget.tagSave.extraData.ultralightVersion);
    ultralightSignatureController.text =
        bytesToHexSpace(widget.tagSave.extraData.ultralightSignature);

    // Initialize counter controllers
    initCounterControllers();

    nameController.text = widget.tagSave.name;
    pickerColor = widget.tagSave.color;
    currentColor = widget.tagSave.color;

    originalUid = widget.tagSave.uid;
    originalSak = bytesToHexSpace(u8ToBytes(widget.tagSave.sak));
    originalAtqa = bytesToHexSpace(widget.tagSave.atqa);
  }

  bool hasDataChanged() {
    return uidController.text != originalUid ||
        sakController.text != originalSak ||
        atqaController.text != originalAtqa;
  }

  Future<bool> showUpdateDataDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(localizations.update_data_title),
              content: Text(localizations.update_data_message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(localizations.no),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(localizations.yes),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  List<Uint8List> updateCardData(List<Uint8List> originalData) {
    List<Uint8List> updatedData = List.from(originalData);

    if (isMifareClassic(selectedType)) {
      final uid = hexToBytes(uidController.text);
      final sak = hexToBytes(sakController.text)[0];
      final atqa = hexToBytes(atqaController.text);

      updatedData[0] = mfClassicGenerateFirstBlock(uid, sak, atqa);
    } else if (isMifareUltralight(selectedType)) {
      final uid = hexToBytes(uidController.text);
      final newBlocks = mfUltralightGenerateFirstBlocks(uid, selectedType);

      for (int i = 0; i < newBlocks.length && i < updatedData.length; i++) {
        updatedData[i] = newBlocks[i];
      }
    }

    return updatedData;
  }

  void initCounterControllers() {
    ultralightCounterControllers.clear();
    int counterCount = mfUltralightGetCounterCount(selectedType);

    for (int i = 0; i < counterCount; i++) {
      TextEditingController controller = TextEditingController();
      if (i < widget.tagSave.extraData.ultralightCounters.length) {
        controller.text =
            widget.tagSave.extraData.ultralightCounters[i].toString();
      } else {
        controller.text = '0';
      }
      ultralightCounterControllers.add(controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<ChameleonGUIState>();
    var localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localizations.edit_card),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizations.please_enter_name;
                  }
                  if (value.length > 19) {
                    return localizations.too_long_name;
                  }
                  return null;
                },
                decoration: InputDecoration(
                    labelText: localizations.name,
                    hintText: localizations.enter_name_of_card,
                    prefix: Transform(
                        transform: Matrix4.translationValues(0, 7, 0),
                        child: IconButton(
                          icon: Icon(
                              (chameleonTagToFrequency(widget.tagSave.tag) ==
                                      TagFrequency.hf)
                                  ? Icons.credit_card
                                  : Icons.wifi,
                              color: currentColor),
                          onPressed: () async {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text(localizations.pick_color),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: pickerColor,
                                      onColorChanged: (Color color) {
                                        setState(() {
                                          pickerColor = color;
                                        });
                                      },
                                      pickerAreaHeightPercent: 0.8,
                                    ),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () {
                                        setState(() => currentColor =
                                            pickerColor = Colors.deepOrange);
                                        Navigator.pop(context);
                                      },
                                      child: Text(localizations.reset_default),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: Text(localizations.cancel),
                                    ),
                                    TextButton(
                                      child: Text(localizations.ok),
                                      onPressed: () {
                                        setState(
                                            () => currentColor = pickerColor);
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ))),
              ),
              const SizedBox(height: 8),
              DropdownButton<TagType>(
                value: selectedType,
                items: getTagTypes()
                    .map<DropdownMenuItem<TagType>>((TagType type) {
                  return DropdownMenuItem<TagType>(
                    value: type,
                    child: Text(
                      chameleonTagToString(type),
                    ),
                  );
                }).toList(),
                onChanged: (TagType? newValue) {
                  if (newValue! != TagType.unknown) {
                    setState(() {
                      selectedType = newValue;
                      // Reinitialize counter controllers when tag type changes
                      initCounterControllers();
                    });
                  }
                  appState.changesMade();
                },
              ),
              Visibility(
                visible: selectedType != TagType.unknown,
                child: Column(children: [
                  TextFormField(
                    controller: uidController,
                    decoration: InputDecoration(
                        labelText: localizations.uid,
                        hintText:
                            localizations.enter_something(localizations.uid)),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9A-Fa-f: ]'))
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations
                            .please_enter_something(localizations.uid);
                      }
                      if (!(value.replaceAll(" ", "").length == 14 ||
                              value.replaceAll(" ", "").length == 8 ||
                              value.replaceAll(" ", "").length == 20) &&
                          chameleonTagToFrequency(selectedType) !=
                              TagFrequency.lf) {
                        return localizations.must_or(
                            "4, 7", "10", localizations.uid);
                      }
                      if (value.replaceAll(" ", "").length != 10 &&
                          chameleonTagToFrequency(selectedType) ==
                              TagFrequency.lf) {
                        return localizations.must_be(5, localizations.uid);
                      }
                      return null;
                    },
                  ),
                  Visibility(
                      visible: chameleonTagToFrequency(selectedType) !=
                          TagFrequency.lf,
                      child: Column(children: [
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: sakController,
                          decoration: InputDecoration(
                              labelText: localizations.sak,
                              hintText: localizations
                                  .enter_something(localizations.sak)),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9A-Fa-f: ]'))
                          ],
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty &&
                                    chameleonTagToFrequency(selectedType) !=
                                        TagFrequency.lf) {
                              return localizations
                                  .please_enter_something(localizations.sak);
                            }
                            if (value.replaceAll(" ", "").length != 2 &&
                                chameleonTagToFrequency(selectedType) !=
                                    TagFrequency.lf) {
                              return localizations.must_be(
                                  1, localizations.sak);
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: atqaController,
                          decoration: InputDecoration(
                              labelText: localizations.atqa,
                              hintText: localizations
                                  .enter_something(localizations.atqa)),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9A-Fa-f: ]'))
                          ],
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty &&
                                    chameleonTagToFrequency(selectedType) !=
                                        TagFrequency.lf) {
                              return localizations
                                  .please_enter_something(localizations.atqa);
                            }
                            if (value.replaceAll(" ", "").length != 4 &&
                                chameleonTagToFrequency(selectedType) !=
                                    TagFrequency.lf) {
                              return localizations.must_be(
                                  2, localizations.atqa);
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                            controller: atsController,
                            decoration: InputDecoration(
                                labelText: localizations.ats,
                                hintText: localizations
                                    .enter_something(localizations.ats)),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9A-Fa-f: ]'))
                            ],
                            validator: (value) {
                              if (value!.replaceAll(" ", "").length % 2 != 0) {
                                return localizations.must_be_valid_hex;
                              }
                              return null;
                            }),
                        if (isMifareUltralight(selectedType)) ...[
                          const SizedBox(height: 20),
                          TextFormField(
                              controller: ultralightVersionController,
                              decoration: InputDecoration(
                                  labelText: localizations.ultralight_version,
                                  hintText: localizations.enter_something(
                                      localizations.ultralight_version)),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9A-Fa-f: ]'))
                              ],
                              validator: (value) {
                                if (value!.replaceAll(" ", "").length % 2 !=
                                    0) {
                                  return localizations.must_be_valid_hex;
                                }

                                if (value.isNotEmpty &&
                                    value.replaceAll(" ", "").length != 16 &&
                                    isMifareUltralight(selectedType)) {
                                  return localizations.must_be(
                                      8, localizations.ultralight_version);
                                }

                                return null;
                              }),
                          const SizedBox(height: 20),
                          TextFormField(
                              controller: ultralightSignatureController,
                              decoration: InputDecoration(
                                  labelText: localizations.ultralight_signature,
                                  hintText: localizations.enter_something(
                                      localizations.ultralight_signature)),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9A-Fa-f: ]'))
                              ],
                              validator: (value) {
                                if (value!.replaceAll(" ", "").length % 2 !=
                                    0) {
                                  return localizations.must_be_valid_hex;
                                }
                                return null;
                              }),
                          if (mfUltralightHasCounters(selectedType)) ...[
                            const SizedBox(height: 20),
                            ...ultralightCounterControllers
                                .asMap()
                                .entries
                                .map((entry) {
                              int index = entry.key;
                              TextEditingController controller = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TextFormField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                      labelText: localizations
                                          .ultralight_counter(index),
                                      hintText: localizations
                                          .ultralight_counter_value),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return localizations.counter_value_empty;
                                    }
                                    int? counterValue = int.tryParse(value);
                                    if (counterValue == null ||
                                        counterValue < 0 ||
                                        counterValue > 16777215) {
                                      return localizations.counter_value_range;
                                    }
                                    return null;
                                  },
                                ),
                              );
                            }),
                          ],
                        ]
                      ]))
                ]),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(localizations.cancel),
        ),
        TextButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            List<Uint8List> cardData = widget.tagSave.data;

            if (hasDataChanged() &&
                (isMifareClassic(selectedType) ||
                    isMifareUltralight(selectedType))) {
              bool shouldUpdateData = await showUpdateDataDialog(context);
              if (shouldUpdateData) {
                cardData = updateCardData(widget.tagSave.data);
              }
            }

            var tag = CardSave(
                id: widget.tagSave.id,
                name: nameController.text,
                sak: chameleonTagToFrequency(selectedType) == TagFrequency.lf
                    ? widget.tagSave.sak
                    : hexToBytes(sakController.text)[0],
                atqa: hexToBytes(atqaController.text),
                uid: bytesToHexSpace(hexToBytes(uidController.text)),
                extraData: CardSaveExtra(
                  ultralightSignature:
                      hexToBytes(ultralightSignatureController.text),
                  ultralightVersion:
                      hexToBytes(ultralightVersionController.text),
                  ultralightCounters: ultralightCounterControllers
                      .map((controller) => int.tryParse(controller.text) ?? 0)
                      .toList(),
                ),
                tag: selectedType,
                data: cardData,
                color: currentColor,
                ats: hexToBytes(atsController.text));

            var tags = appState.sharedPreferencesProvider.getCards();
            var index =
                tags.indexWhere((element) => element.id == widget.tagSave.id);

            if (index != -1) {
              tags[index] = tag;
            }

            appState.sharedPreferencesProvider.setCards(tags);
            appState.changesMade();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: Text(localizations.save),
        ),
      ],
    );
  }
}
