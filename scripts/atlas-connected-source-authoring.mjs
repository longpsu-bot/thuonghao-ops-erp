// Executed only by the guarded disposable Procurement browser driver.
import assert from "node:assert/strict";
import { controlledInputExpression } from "./staging-planning-browser.mjs";

export async function certifyMasterSourceAuthoring({
  connection,
  evaluate,
  until,
  operator,
  subject,
  sql,
  url,
}) {
  const date = "2050-09-26";
  const rpc = async (name, contract, payload = {}) => {
    assert(
      [
        "get_school_master_data",
        "get_ingredient_supplier_master_data",
        "get_dish_recipe_workbench",
        "get_dish_recipe_operator_workbench",
        "get_planning_inputs_workbench",
        "get_pantry_source_workbench",
      ].includes(name),
    );
    const result = await operator.schema("atlas_api").rpc(name, {
      request: {
        contract_version: contract,
        requested_by_auth_subject: subject,
        correlation_id: crypto.randomUUID(),
        payload,
      },
    });
    assert(
      !result.error && result.data?.success,
      `Authoring public read failed: ${name}/${result.error?.code ?? result.data?.error_code}`,
    );
    return result.data.workbench ?? result.data;
  };
  const master = () => rpc("get_ingredient_supplier_master_data", "RMVP-01.v1");
  const schools = () => rpc("get_school_master_data", "RMVP-01.v1");
  const planning = () =>
    rpc("get_planning_inputs_workbench", "RMVP-03A.v1", { week_start: date });
  const pantry = () =>
    rpc("get_pantry_source_workbench", "PANTRY-02.v1", { week_start: date });
  const recipes = () => rpc("get_dish_recipe_workbench", "RMVP-02A.v1");
  const receipts = (name) =>
    Number(
      sql(
        `select count(*) from atlas_core.command_receipts where command_name='${name}' and outcome='COMPLETED'`,
      ),
    );
  const open = async (stage, selector) => {
    const origin = await evaluate("performance.timeOrigin");
    await connection.send("Page.navigate", { url: `${url}?stage=${stage}` });
    await until(
      () =>
        evaluate(
          `performance.timeOrigin!==${origin}&&document.readyState==='complete'&&Boolean(document.querySelector(${JSON.stringify(selector)}))`,
        ),
      `AUTHORING_${stage}_OPEN`,
    );
  };
  const action = async (label, scope = "body", aria = false) => {
    const expression = `(()=>{const root=document.querySelector(${JSON.stringify(scope)});return [...root?.querySelectorAll('button')??[]].find(b=>${aria ? "b.getAttribute('aria-label')" : "b.textContent.trim()"}===${JSON.stringify(label)}&&!b.disabled&&b.getAttribute('aria-disabled')!=='true');})()`;
    await until(
      () => evaluate(`Boolean(${expression})`),
      `AUTHORING_READY_${label}`,
    );
    assert(
      await evaluate(
        `(()=>{const b=${expression};if(!b)return false;b.click();return true;})()`,
      ),
      `Single action: ${label}`,
    );
  };
  const input = (selector, value, kind) =>
    evaluate(
      kind === "textarea" || kind === "combobox"
        ? `(()=>{const e=document.querySelector(${JSON.stringify(selector)});if(!e||e.disabled)throw Error('AUTHORING_INPUT_DISABLED');e.focus();Object.getOwnPropertyDescriptor(${kind === "textarea" ? "HTMLTextAreaElement" : "HTMLInputElement"}.prototype,'value').set.call(e,${JSON.stringify(value)});e.dispatchEvent(new Event('input',{bubbles:true}));${kind === "textarea" ? "e.blur();" : ""}})()`
        : controlledInputExpression(selector, value, kind),
    );
  const field = async (scope, label, value) => {
    const selector = await evaluate(
      `(()=>{const root=document.querySelector(${JSON.stringify(scope)});const label=[...root.querySelectorAll('label')].find(l=>l.textContent.replaceAll('*','').trim()===${JSON.stringify(label)});const e=label?.control??label?.parentElement.querySelector('input,textarea,select');if(!e||e.disabled)return null;e.setAttribute('data-certification-field','active');return e.tagName.toLowerCase();})()`,
    );
    assert(selector, `Actual field missing: ${scope}/${label}`);
    await input(
      '[data-certification-field="active"]',
      value,
      selector === "select"
        ? "select"
        : selector === "textarea"
          ? "textarea"
          : "input",
    );
    await evaluate(
      "document.querySelector('[data-certification-field=active]').removeAttribute('data-certification-field')",
    );
  };
  const selectFirst = async (scope, label) => {
    const value = await evaluate(
      `(()=>{const root=document.querySelector(${JSON.stringify(scope)});const l=[...root.querySelectorAll('label')].find(l=>l.textContent.replaceAll('*','').trim()===${JSON.stringify(label)});const s=l?.control??l?.parentElement.querySelector('select');return [...s?.options??[]].find(o=>o.value&&!o.disabled)?.value;})()`,
    );
    assert(value, `Active option required: ${label}`);
    await field(scope, label, value);
    return value;
  };
  const fieldValue = (scope, label) =>
    evaluate(
      `(()=>{const root=document.querySelector(${JSON.stringify(scope)});const l=[...root?.querySelectorAll('label')??[]].find(l=>l.textContent.replaceAll('*','').trim()===${JSON.stringify(label)});return (l?.control??l?.parentElement.querySelector('input,textarea,select'))?.value;})()`,
    );
  const readAfter = async (name, original, read, predicate) => {
    await until(
      () => receipts(name) === original + 1,
      `AUTHORING_RECEIPT_${name}`,
    );
    const result = await read();
    assert(predicate(result), `Persisted ${name} result`);
    return result;
  };
  const initialSchools = (await schools()).schools;
  const school = initialSchools.find(
    (s) =>
      s.school_status === "ACTIVE" &&
      s.school_code === "effective-generation-school-1",
  );
  assert(school, "Known synthetic source School required.");
  assert.equal(school.school_id, "a7400000-0000-4000-8000-000000005001");
  assert(
    !(await planning()).attendance && !(await pantry()).batch,
    "Author only the unused isolated week.",
  );
  await open(
    "schools",
    'input[aria-label^="Học sinh mặc định"]:not(:disabled)',
  );
  const schoolInput = `input[aria-label=${JSON.stringify(`Học sinh mặc định — ${school.school_name}`)}]`;
  const desired = school.default_student_portions + 7;
  await input(schoolInput, "-1");
  assert(
    await evaluate(
      "[...document.querySelectorAll('button')].find(b=>b.textContent.trim()==='Lưu sĩ số')?.disabled",
    ),
  );
  await input(schoolInput, String(desired));
  const schoolReceipts = receipts("update_school_portion_defaults_bulk");
  await action("Lưu sĩ số");
  const updatedSchools = (
    await readAfter(
      "update_school_portion_defaults_bulk",
      schoolReceipts,
      schools,
      (data) =>
        data.schools.some(
          (s) =>
            s.school_id === school.school_id &&
            s.default_student_portions === desired,
        ),
    )
  ).schools;
  for (const old of initialSchools) {
    const next = updatedSchools.find((s) => s.school_id === old.school_id);
    if (old.school_id !== school.school_id) assert.deepEqual(next, old);
    else {
      assert.equal(next.version, old.version + 1);
      assert.equal(next.default_teacher_portions, old.default_teacher_portions);
    }
  }
  await open("schools", schoolInput);
  assert.equal(
    await evaluate(
      `document.querySelector(${JSON.stringify(schoolInput)}).value`,
    ),
    String(desired),
  );

  await open("suppliers", 'section[aria-label="Nhà cung ứng"]');
  await action("Tạo nhà cung ứng");
  const supplierScope = 'aside[aria-label="Chi tiết nhà cung ứng"]';
  const supplierName = "Disposable browser supplier";
  await field(supplierScope, "Tên nhà cung ứng", supplierName);
  await field(supplierScope, "Mã NCC trên chứng từ", "BROWSER-SUPPLIER");
  await field(supplierScope, "Email", "operator@local.test");
  await action("Xem thay đổi", supplierScope);
  const supplierReceipts = receipts("create_supplier");
  await action("Lưu nhà cung ứng");
  const supplier = (
    await readAfter("create_supplier", supplierReceipts, master, (data) =>
      data.suppliers.some((s) => s.supplier_name === supplierName),
    )
  ).suppliers.find((s) => s.supplier_name === supplierName);
  assert(supplier.supplier_code.startsWith("supplier-"));
  assert.equal(supplier.document_code, "BROWSER-SUPPLIER");
  await open("suppliers", 'input[aria-label="Tìm nhà cung ứng"]');
  await input('input[aria-label="Tìm nhà cung ứng"]', supplierName);
  await until(
    () =>
      evaluate(
        `document.body.innerText.includes(${JSON.stringify(supplierName)})`,
      ),
    "AUTHORING_SUPPLIER_REOPEN",
  );
  assert.equal(
    (await master()).suppliers.filter((s) => s.supplier_name === supplierName)
      .length,
    1,
  );
  await action(`Xem / sửa ${supplierName}`, "body", true);
  assert.equal(
    await fieldValue(supplierScope, "Tên nhà cung ứng"),
    supplierName,
  );
  assert.equal(
    await fieldValue(supplierScope, "Mã NCC trên chứng từ"),
    "BROWSER-SUPPLIER",
  );
  assert.equal(await fieldValue(supplierScope, "Email"), "operator@local.test");

  await open("ingredients", 'section[aria-label="Nguyên liệu"]');
  await action("Tạo nguyên liệu");
  const ingredientScope = 'aside[aria-label="Chi tiết nguyên liệu"]';
  const ingredientName = "Disposable browser ingredient";
  await field(ingredientScope, "Tên nguyên liệu", ingredientName);
  const unitId = await selectFirst(ingredientScope, "Đơn vị mua");
  const typeId = await selectFirst(ingredientScope, "Loại nguyên liệu");
  const groupId = await selectFirst(ingredientScope, "Nhóm đặt hàng");
  await field(ingredientScope, "Bước làm tròn mặc định", "0");
  assert(
    await evaluate(
      `(()=>{const root=document.querySelector(${JSON.stringify(ingredientScope)});return [...root.querySelectorAll('button')].find(b=>b.textContent.trim()==='Xem thay đổi')?.disabled===true&&root.querySelector('[aria-invalid=true]')!==null;})()`,
    ),
  );
  await field(ingredientScope, "Bước làm tròn mặc định", "0,1");
  await action("Xem thay đổi", ingredientScope);
  const ingredientReceipts = receipts("create_ingredient");
  await action("Lưu nguyên liệu");
  const ingredient = (
    await readAfter("create_ingredient", ingredientReceipts, master, (data) =>
      data.ingredients.some((i) => i.ingredient_name === ingredientName),
    )
  ).ingredients.find((i) => i.ingredient_name === ingredientName);
  assert(ingredient.ingredient_code.startsWith("ingredient-"));
  assert.equal(ingredient.purchase_unit_id, unitId);
  assert.equal(ingredient.ingredient_type_id, typeId);
  assert.equal(ingredient.ingredient_order_group_id, groupId);
  assert.equal(String(ingredient.order_step), "0.1");
  await open("ingredients", 'input[aria-label="Tìm nguyên liệu"]');
  await input('input[aria-label="Tìm nguyên liệu"]', ingredientName);
  await until(
    () =>
      evaluate(
        `document.body.innerText.includes(${JSON.stringify(ingredientName)})`,
      ),
    "AUTHORING_INGREDIENT_REOPEN",
  );
  await action(`Xem / sửa ${ingredientName}`, "body", true);
  assert.equal(
    await fieldValue(ingredientScope, "Tên nguyên liệu"),
    ingredientName,
  );
  assert.equal(await fieldValue(ingredientScope, "Đơn vị mua"), unitId);
  assert.equal(await fieldValue(ingredientScope, "Loại nguyên liệu"), typeId);
  assert.equal(await fieldValue(ingredientScope, "Nhóm đặt hàng"), groupId);
  assert.equal(
    (await fieldValue(ingredientScope, "Bước làm tròn mặc định")).replace(
      ",",
      ".",
    ),
    "0.1",
  );
  const updatesBeforeDiscard = receipts("update_ingredient");
  const ingredientBeforeDiscard = (await master()).ingredients.find(
    (i) => i.ingredient_id === ingredient.ingredient_id,
  );
  await field(ingredientScope, "Tên nguyên liệu", "Disposable discarded edit");
  await action("Đóng", ingredientScope);
  await action("Tiếp tục chỉnh sửa", "[role=dialog]");
  assert.equal(
    await fieldValue(ingredientScope, "Tên nguyên liệu"),
    "Disposable discarded edit",
  );
  await until(
    () => evaluate("!document.querySelector('[role=dialog]')"),
    "AUTHORING_DIRTY_CANCEL",
  );
  await action("Đóng", ingredientScope);
  await action("Bỏ thay đổi", "[role=dialog]");
  await until(
    () =>
      evaluate(`!document.querySelector(${JSON.stringify(ingredientScope)})`),
    "AUTHORING_DIRTY_DISCARD",
  );
  await action(`Xem / sửa ${ingredientName}`, "body", true);
  assert.equal(
    await fieldValue(ingredientScope, "Tên nguyên liệu"),
    ingredientName,
  );
  assert.equal(receipts("create_ingredient"), ingredientReceipts + 1);
  assert.equal(receipts("update_ingredient"), updatesBeforeDiscard);
  assert.deepEqual(
    (await master()).ingredients.find(
      (i) => i.ingredient_id === ingredient.ingredient_id,
    ),
    ingredientBeforeDiscard,
    "Cancel/Discard must not persist any Ingredient change.",
  );

  await open("recipes", 'section[aria-label="Công thức"]');
  await action("Tạo món mới");
  const recipeScope = 'section[aria-label="Công thức"]';
  const dishName = "Disposable browser dish";
  await field(recipeScope, "Tên món", dishName);
  const dishType = await selectFirst(recipeScope, "Loại món của món");
  const dishReceipts = receipts("create_dish");
  await action("Tạo món", recipeScope);
  const dish = (
    await readAfter("create_dish", dishReceipts, recipes, (data) =>
      data.dishes.some((d) => d.dish_name === dishName),
    )
  ).dishes.find((d) => d.dish_name === dishName);
  assert.equal(dish.dish_type_id, dishType);
  await until(
    () =>
      evaluate(
        `Boolean(document.querySelector('input[placeholder="Tìm nguyên liệu để thêm…"]:not(:disabled)'))`,
      ),
    "AUTHORING_RECIPE_EDITOR",
  );
  await field(recipeScope, "Số suất áp dụng cho định lượng", "100");
  await field(recipeScope, "Tìm nguyên liệu để thêm", ingredientName);
  await action(`Thêm ${ingredientName}`, recipeScope, true);
  await input(
    `input[aria-label=${JSON.stringify(`Định lượng ${ingredientName}`)}]`,
    "2,5",
  );
  const selectedType = await evaluate(
    "[...document.querySelectorAll('select')].find(s=>[...s.options].some(o=>o.value==='a7400000-0000-4000-8000-000000000012'))?.value",
  );
  assert(selectedType, "Actual selected canonical recipe scope required.");
  await action("Xem thay đổi", recipeScope);
  const recipeReceipts = receipts("save_recipe");
  await action("Lưu công thức", recipeScope);
  const effective = () =>
    rpc("get_dish_recipe_operator_workbench", "RECIPE-EFFECTIVE.v1", {
      as_of_date: date,
      dish_id: dish.dish_id,
      school_type_id: selectedType,
    });
  const savedRecipe = await readAfter(
    "save_recipe",
    recipeReceipts,
    effective,
    (data) => data.base_authoring?.basis_portions === 100,
  );
  const composition = savedRecipe.base_authoring.composition.filter(
    (l) => l.line_disposition === "PRESENT",
  );
  assert.equal(composition.length, 1);
  assert.equal(composition[0].ingredient_id, ingredient.ingredient_id);
  assert.equal(String(composition[0].quantity_per_basis), "2.5");
  assert.equal(composition[0].unit_id, unitId);
  await open("recipes", recipeScope);
  await field(recipeScope, "Tìm món", dishName);
  await until(
    () =>
      evaluate(`document.body.innerText.includes(${JSON.stringify(dishName)})`),
    "AUTHORING_DISH_REOPEN",
  );
  await action(`Sửa công thức ${dishName}`, recipeScope, true);
  await until(
    () =>
      evaluate(
        `document.querySelector('input[aria-label=${JSON.stringify(`Định lượng ${ingredientName}`)}]')?.value==='2,5'`,
      ),
    "AUTHORING_RECIPE_QUANTITY_REOPEN",
  );
  assert.deepEqual(await effective(), savedRecipe);

  await open("attendance", 'select[aria-label="Ngày phục vụ"]');
  await action("Dán hàng loạt");
  await input(
    'textarea[aria-label="Dữ liệu dán"]',
    `${school.school_code}\t${date}\t12\t0`,
    "textarea",
  );
  await action("Dùng dữ liệu dán");
  await action("Xem thay đổi");
  const attendanceReceipts = receipts("save_attendance");
  await action("Lưu");
  const savedAttendance = (
    await readAfter("save_attendance", attendanceReceipts, planning, (data) =>
      Boolean(data.attendance),
    )
  ).attendance;
  const attendanceLines = savedAttendance.lines.filter(
    (l) => l.line_status === "ACTIVE",
  );
  assert.equal(attendanceLines.length, 1);
  assert.equal(attendanceLines[0].school_id, school.school_id);
  assert.equal(attendanceLines[0].service_date, date);
  assert.equal(attendanceLines[0].student_portions, 12);
  assert.equal(attendanceLines[0].teacher_portions, 0);
  await open(
    "attendance",
    `input[aria-label=${JSON.stringify(`Học sinh ${school.school_name}`)}]`,
  );
  assert.equal(
    await evaluate(
      `document.querySelector('input[aria-label=${JSON.stringify(`Học sinh ${school.school_name}`)}]').value`,
    ),
    "12",
  );
  assert.deepEqual((await planning()).attendance, savedAttendance);
  const readiness = (await planning()).readiness;
  assert.equal(readiness.attendance_approved, true);
  assert.equal(readiness.weekly_menu_approved, false);
  assert.equal(
    readiness.ready,
    false,
    "Missing external Menu remains an explicit prerequisite; saved Attendance cannot manufacture readiness.",
  );

  await open(
    "pantry",
    'input[aria-label="Trường cần thêm hàng"]:not(:disabled)',
  );
  await input(
    'input[aria-label="Trường cần thêm hàng"]',
    school.school_name,
    "combobox",
  );
  const schoolOption = `[role=option][id$="-school-${school.school_id}"]:not([aria-disabled=true])`;
  await until(
    () =>
      evaluate(
        `Boolean(document.querySelector(${JSON.stringify(schoolOption)}))`,
      ),
    "AUTHORING_PANTRY_SCHOOL",
  );
  await evaluate(
    `document.querySelector(${JSON.stringify(schoolOption)}).click()`,
  );
  const pantryScope = 'section[aria-label="Hàng đặt riêng"]';
  for (const [index, purpose, quantity] of [
    [1, "planning_identified_supplement", "2"],
    [2, "school_requested_supplement", "3"],
  ]) {
    await field(pantryScope, "Nguồn của dòng mới", purpose);
    await action("+ Thêm dòng");
    const chooser = `input[aria-label="Nguyên liệu dòng ${index}"]`;
    await input(chooser, ingredientName, "combobox");
    const ingredientOption = `[role=listbox][aria-label="Nguyên liệu dòng ${index}"] [role=option][id$="-option-${ingredient.ingredient_id}"]:not([aria-disabled=true])`;
    await until(
      () =>
        evaluate(
          `Boolean(document.querySelector(${JSON.stringify(ingredientOption)}))`,
        ),
      "AUTHORING_PANTRY_INGREDIENT",
    );
    await evaluate(
      `document.querySelector(${JSON.stringify(ingredientOption)}).click()`,
    );
    await input(`input[aria-label="Số lượng dòng ${index}"]`, quantity);
  }
  await action("Xem thay đổi");
  const pantryReceipts = receipts("save_pantry");
  await action("Lưu");
  const savedPantry = (
    await readAfter("save_pantry", pantryReceipts, pantry, (data) =>
      Boolean(data.batch),
    )
  ).batch;
  assert.equal(savedPantry.active_lines.length, 2);
  assert.equal(savedPantry.no_additions_confirmed, false);
  assert.deepEqual(savedPantry.school_date_modes, [
    {
      school_id: school.school_id,
      service_date: date,
      direct_need_mode: "ADDITIVE",
    },
  ]);
  const purposes = savedPantry.active_lines
    .map((l) => ({
      school: l.school_id,
      date: l.service_date,
      ingredient: l.ingredient_id,
      unit: l.unit_id,
      purpose: l.purpose_code,
      quantity: String(l.requested_quantity)
        .replace(/(\.\d*?)0+$/, "$1")
        .replace(/\.$/, ""),
    }))
    .sort((a, b) => a.purpose.localeCompare(b.purpose));
  assert.deepEqual(purposes, [
    {
      school: school.school_id,
      date,
      ingredient: ingredient.ingredient_id,
      unit: unitId,
      purpose: "planning_identified_supplement",
      quantity: "2",
    },
    {
      school: school.school_id,
      date,
      ingredient: ingredient.ingredient_id,
      unit: unitId,
      purpose: "school_requested_supplement",
      quantity: "3",
    },
  ]);
  await open("pantry", 'input[aria-label="Số lượng dòng 1"]');
  assert.deepEqual(
    await evaluate(
      "[...document.querySelectorAll('input[aria-label^=\"Số lượng dòng\"]')].map(e=>e.value).sort()",
    ),
    ["2", "3"],
  );
  assert.deepEqual((await pantry()).batch, savedPantry);
  return {
    status: "PASS",
    week: date,
    school: school.school_id,
    supplier: supplier.supplier_id,
    ingredient: ingredient.ingredient_id,
    dish: dish.dish_id,
    schoolType: selectedType,
    unit: unitId,
    sourceLines: 3,
    teacherZeroPreserved: true,
    nativeCommands: 7,
    savedRecipeLines: 1,
  };
}
